/// Service for validating inputs sent via socket
/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/InputValidator)
module tagion.services.inputvalidator;

import core.sys.posix.unistd : getuid;
import std.socket;
import std.stdio;
import std.path;
import std.algorithm : remove;

import tagion.actor;
import core.time;
import tagion.utils.pretend_safe_concurrency;
import tagion.script.StandardRecords;
import tagion.network.ReceiveBuffer;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.basic.basic : forceRemove;
import tagion.basic.Debug : __write;
import tagion.GlobalSignals : stopsignal;
import tagion.utils.JSONCommon;

/// Msg Type sent to actors who receive the document
alias inputDoc = Msg!"inputDoc";

@property
static immutable(string) contract_sock_path() @safe nothrow {
    version (linux) {
        return "\0NEUEWELLE_CONTRACT";
    }
    else version (Posix) {
        import std.exception;
        import std.conv;

        const uid = assumeWontThrow(getuid.to!string);
        return buildPath("/", "run", "user", uid, "tagionwave_contract.sock");
    }
    else {
        assert(0, "Unsupported platform");
    }
}

struct InputValidatorOptions {
    uint mbox_timeout = 10; // msecs
    uint socket_select_timeout = 1000; // msecs
    uint max_connections = 1;
    mixin JSONCommon;
}

struct InputValidatorService {
    static InputValidatorOptions options;

    static void task(string task_name, string receiver_task, string sock_path) nothrow {
        try {
            bool stop = false;
            setState(Ctrl.STARTING);
            auto listener = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            assert(listener.isAlive);
            listener.blocking = false;
            listener.bind(new UnixAddress(sock_path));
            listener.listen(1);
            writefln("Listening on address %s.", sock_path);
            scope (exit) {
                writefln("Closing listener %s", sock_path);
                listener.close();
                assert(!listener.isAlive);
                end();
            }

            auto socketSet = new SocketSet(options.max_connections + 1); // Room for listener.
            Socket[] reads;
            ReceiveBuffer buf;

            setState(Ctrl.ALIVE);
            eventloop: while (true) {
                try {
                    receiveTimeout(options.mbox_timeout.msecs,
                            (Sig sig) {
                        if (sig is Sig.STOP) {
                            writeln("Input validator service received stop signal");
                            stop = true;
                        }
                    }
                    );
                    if (stop)
                        break eventloop;

                    socketSet.add(listener);

                    foreach (sock; reads)
                        socketSet.add(sock);

                    Socket.select(socketSet, null, null, options.socket_select_timeout.msecs);

                    for (size_t i = 0; i < reads.length; i++) {
                        if (socketSet.isSet(reads[i])) {
                            auto result = buf.append(&reads[i].receive);
                            Document doc = Document(cast(immutable) result.data);
                            __write("Received %d bytes.", result.size);
                            __write("Document status code %s", doc.valid);
                            if (result.size != 0 && doc.valid is Document.Element.ErrorCode.NONE && doc.isRecord!(HiRPC
                                    .Sender)) {
                                __write("sending to %s", receiver_task);
                                locate(receiver_task).send(inputDoc(), doc);
                            }
                            // release socket resources now
                            reads[i].close();
                            reads = reads.remove(i);
                            // i will be incremented by the for, we don't want it to be.
                            i--;
                        }
                    }

                    /// Accept incoming reguests
                    if (socketSet.isSet(listener)) {
                        Socket sn = null;
                        scope (failure) {
                            writefln("Error accepting");

                            if (sn)
                                sn.close();
                        }
                        sn = listener.accept();
                        assert(sn.isAlive);
                        assert(listener.isAlive);

                        if (reads.length < options.max_connections) {
                            writefln("Connection established.");
                            reads ~= sn;
                        }
                        else {
                            writefln("Rejected connection; too many connections.");
                            sn.close();
                            assert(!sn.isAlive);
                            assert(listener.isAlive);
                        }
                    }
                    socketSet.reset();
                }
                catch (Exception e) {
                    fail(e);
                }
            }
        }
        catch (Exception e) {
            fail(e);
        }
    }
}

alias InputValidatorHandle = ActorHandle!InputValidatorService;
