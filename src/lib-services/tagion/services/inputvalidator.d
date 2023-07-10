module tagion.services.inputvalidator;

import core.sys.posix.unistd : getuid;
import std.socket;
import std.stdio;
import std.path;
import std.algorithm : remove;

import tagion.actor;
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

alias inputDoc = Msg!"inputDoc";

@property
static immutable(string) contract_sock_path() nothrow {
    version (linux) {
        return "\0NEUEWELLE_CONTRACT";
    }
    else version (Posix) {
        return buildPath("/", "run", "user", format("%d", getuid), "tagionwave_contract.sock");
    }
    else {
        assert(0, "Unsupported platform");
    }
}

void inputvalidator(string receiver_task) nothrow {
    try {
        auto listener = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        assert(listener.isAlive);
        listener.blocking = false;
        listener.bind(new UnixAddress(contract_sock_path));
        listener.listen(1);
        writefln("Listening on address %s.", contract_sock_path);

        enum MAX_CONNECTIONS = 1;
        // Room for listener.
        auto socketSet = new SocketSet(MAX_CONNECTIONS + 1);
        Socket[] reads;

        ReceiveBuffer buf;
        while (true) {
            socketSet.add(listener);

            foreach (sock; reads)
                socketSet.add(sock);

            Socket.select(socketSet, null, null);

            for (size_t i = 0; i < reads.length; i++) {
                if (socketSet.isSet(reads[i])) {
                    auto result = buf.append(&reads[i].receive);
                    Document doc = Document(cast(immutable) result.data);
                    __write("Received %d bytes.", result.size);
                    __write("Document status code %s", doc.valid);
                    if (result.size != 0 && doc.valid is Document.Element.ErrorCode.NONE) {
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

                if (reads.length < MAX_CONNECTIONS) {
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
    }
    catch (Exception e) {
        fail("inputvalidator", e);
    }
}
