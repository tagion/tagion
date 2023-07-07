module tagion.services.contract;

import core.sys.posix.unistd : getuid;
import std.socket;
import std.stdio;
import std.path;
import std.algorithm : remove;
import std.exception : enforce;

import tagion.actor;
import tagion.script.StandardRecords;
import tagion.network.ReceiveBuffer;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.basic.basic : forceRemove;
import tagion.GlobalSignals : stopsignal;

@property static immutable(string) contract_sock_path() {
    version (linux) {
        return "\0NEUEWELLE_CONTRACT";
    }
    else {
        enforce(0, "Abstract socket address not supported on platform, please implement with file system addresses");
        // return buildPath("/", "run", "user", format("%d", getuid), "tagionwave_contract.sock");
    }
}

void echoSock(immutable Socket _sock) {
    Socket sock = cast(Socket) _sock;
    ReceiveBuffer buf;
    auto result = buf.append(&sock.receive);
    immutable ubyte[] data = result.data.dup;
    Document doc = Document(data);
    writeln("HiBON status code: ", doc.valid);
    assert(doc.valid is Document.Element.ErrorCode.NONE, "Message is not valid, not a HiBON Document");

    writefln("Received document of length: %s", doc.length);
    assert(doc.isRecord!(HiRPC.Sender), "Message is not a hirpc sender record");
    assert(doc.isRecord!(HiRPC.Receiver), "Message is not a hirpc receiver record");

    writeln(doc.toPretty);
}

struct ContractService {
    static void task(string task_name) nothrow {
        try {
            writeln("contract_sock_path: ", contract_sock_path);
            Socket listener = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            listener.blocking = false;
            listener.bind(new UnixAddress(contract_sock_path));
            enum MAX_CONNECTIONS = 10;
            listener.listen(MAX_CONNECTIONS);

            auto socketSet = new SocketSet(MAX_CONNECTIONS + 1);

            Socket[] reads;

            setState(Ctrl.ALIVE, task_name); // Tell the owner that you are running
            while (!stopsignal.wait) {
                socketSet.add(listener);

                foreach (sock; reads) {
                    socketSet.add(sock);
                }
                Socket.select(socketSet, null, null);

                for (size_t i = 0; i < reads.length; i++) {
                    if (socketSet.isSet(reads[i])) {
                        ReceiveBuffer buf;
                        buf.append(&reads[i].receive);
                        reads[i].close();
                        reads = reads.remove(i);
                        i--;

                        writefln("\tTotal connections: %d", reads.length);
                    }
                }
                if (socketSet.isSet(listener)) // connection request 
                {
                    Socket sn = null;
                    scope (failure) {
                        writefln("error accepting");

                        if (sn)
                            sn.close();
                    }
                    sn = listener.accept();
                    assert(sn.isAlive);
                    assert(listener.isAlive);

                    if (reads.length < MAX_CONNECTIONS) {
                        writefln("connection from %s established.", sn.remoteAddress().toString());
                        reads ~= sn;
                        writefln("\ttotal connections: %d", reads.length);
                    }
                    else {
                        writefln("rejected connection from %s; too many connections.", sn.remoteAddress().toString());
                        sn.close();
                        assert(!sn.isAlive);
                        assert(listener.isAlive);
                    }
                }

                socketSet.reset();
            }

            end(task_name);
        }
        catch (Exception e) {
            fail(task_name, e);
        }
    }
}

alias ContractServiceHandle = ActorHandle!ContractService;
