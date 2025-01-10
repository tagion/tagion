module tagion.dart.DARTRemoteSynchronizer;

import tagion.dart.synchronizer;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.communication.HiRPC;
import nngd;
import std.exception;
import core.time;
import tagion.hibon.Document;
import std.format;
import std.stdio;

// Constants for configuration
enum SOCKET_TIMEOUT = 1000.msecs;

@safe
class DARTRemoteSynchronizer : JournalSynchronizer {
    protected DART destination;
    string src_sock_addr;
    this(BlockFile journalFile, DART destination, string src_sock_addr){
        this.destination = destination;
        this.src_sock_addr = src_sock_addr;
        super(journalFile);
    }

    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request){
        Document send_remote_request(const Document request_doc){
            NNGSocket socket = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            scope(exit) socket.close();

            socket.recvtimeout = SOCKET_TIMEOUT;

            int rc;
            rc = socket.dial(src_sock_addr);
            enforce(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        
            rc = socket.send!(immutable(ubyte[]))(request_doc.serialize);
            enforce(rc == 0, format("Failed to send %s", nng_errstr(rc)));

            writefln("Query send doc: ", request_doc.toPretty);
            
            auto receivedBytes = socket.receive!(immutable(ubyte[]))();
            return Document(receivedBytes);
        }

        immutable request_doc = request.toDoc;
        (() @trusted { fiber.yield; })();
        const response_doc = send_remote_request(request_doc);
        const received = destination.hirpc.receive(response_doc);
        return received;
    }

    override void finish(){
        _finished = true;
    }
}