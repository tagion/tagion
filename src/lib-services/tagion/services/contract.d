module tagion.services.contract;

import std.socket;
import std.stdio;
import std.path;
import core.sys.posix.unistd : getuid;

import tagion.actor;
import tagion.script.StandardRecords;
import tagion.network.ReceiveBuffer;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.basic.basic : forceRemove;

string contract_sock_path() {
    return buildPath("/", "run", "user", format("%s", getuid), "tagionwave_contract.sock");
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
    // runit = false;
}

struct ContractService {
    static void task(string task_name) nothrow {
        try {
            writeln("contract_sock_path: ", contract_sock_path);
            Address addr = new UnixAddress(contract_sock_path);
            Socket sock = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            sock.blocking = true;
            sock.bind(addr);
            enum MAX_CONNECTIONS = 5;
            sock.listen(MAX_CONNECTIONS);

            Socket accept_sock;
            // try {
            //     accept_sock = sock.accept;
            //     spawn(&echoSock, cast(immutable) accept_sock);
            // }
            // catch (SocketOSException e) {
            //     writeln("Socket was closed by os");
            // }

            run(task_name);

            // writeln("exiting");
            sock.close();
            forceRemove(contract_sock_path);

            end(task_name);
        }
        catch (Exception e) {
            fail(task_name, e);
        }
    }
}

alias ContractServiceHandle = ActorHandle!ContractService;
