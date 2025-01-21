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
import std.range;
import core.time : MonoTime;

// Constants for configuration
enum SOCKET_TIMEOUT = 1000.msecs;
enum ATTEMPTS_TIMEOUT = 30_000.msecs;

@safe
class DARTRemoteSynchronizer : JournalSynchronizer {
    protected DART destination;
    string src_sock_addr;
    this(BlockFile journalFile, DART destination, string src_sock_addr) {
        this.destination = destination;
        this.src_sock_addr = src_sock_addr;
        super(journalFile);
    }

    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request) {
        /// Sends a remote request and returns the received document.
        /// Handles socket communication with a timeout and ensures resources are cleaned up.
        Document send_remote_request(const Document request_doc) {

            NNGSocket socket = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            scope (exit) {
                socket.close();
            }

            socket.recvtimeout = SOCKET_TIMEOUT;

            int rc = socket.dial(src_sock_addr);
            enforce(rc == 0, format("Failed to dial %s", nng_errstr(rc)));

            rc = socket.send!(immutable(ubyte[]))(request_doc.serialize);
            enforce(rc == 0, format("Failed to send %s", nng_errstr(rc)));

            const timeout = ATTEMPTS_TIMEOUT;
            auto startTime = MonoTime.currTime();

            // Loop to check receivedBytes with timeout handling
            while (true) {
                auto received = socket.receive!(immutable ubyte[])();
                if (!received.empty) {
                    return Document(received);// Exit the loop if data is received
                }
                // Check if the timeout has elapsed
                if (MonoTime.currTime() - startTime > timeout) {
                    return Document.init; // Exit the loop if received time out waiting for data
                }
                // Yield to avoid blocking while waiting for data
                (() @trusted { fiber.yield; })();
            }
            assert(0);
        }

        const response_doc = send_remote_request(request.toDoc);
        const received = destination.hirpc.receive(response_doc);
        return received;
    }

    override void finish() {
        _finished = true;
    }
}
