/// New wave implementation of the tagion node
module tagion.tools.neuewelle;

// import std.stdio;
import std.format;
import std.getopt;
import tagion.tools.Basic;
import tagion.utils.getopt;
import core.thread;
import std.stdio;
import std.traits : isUnsigned, isNumeric;
import std.socket;
import tagion.basic.Version;
import tagion.tools.revision;
import std.typecons;
import std.path;
import tagion.network.ReceiveBuffer;
import tagion.basic.basic : forceRemove;
import tagion.communication.HiRPC;
import tagion.dart.DARTcrud;
import tagion.hibon.Document;
import tagion.GlobalSignals : abort;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import std.concurrency;

// enum EXAMPLES {
//     ver = Example("-v"),
//     db = Tuple("%s -d %s", program_name, file),
// }

enum contract_sock_path = buildPath("/", "tmp", "tagionwave_contract.sock");

mixin Main!(_main);

int _main(string[] args) {

    bool version_switch;
    immutable program = args[0];

    auto main_args = getopt(args,
            "v|version", "Print revision information", &version_switch
    );

    if (main_args.helpWanted) {
        tagionGetoptPrinter(
                format("Help information for %s\n", program),
                main_args.options
        );
        return 0;
    }

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    writeln("contract_sock_path: ", contract_sock_path);
    Address contract_sock_addr = new UnixAddress(contract_sock_path);
    Socket contract_socket = new Socket(AddressFamily.UNIX, SocketType.STREAM);
    contract_socket.blocking = true;

    scope (exit) {
        contract_socket.close();
        forceRemove(contract_sock_path);
    }

    echoSock(contract_socket, contract_sock_addr);

    return 0;
}

void echoSock(Socket sock, Address addr) @safe {
    bool exit = false;
    sock.bind(addr);
    sock.listen(5);

    while (!abort) {
        ReceiveBuffer buf;
        auto result = buf.append(&sock.accept.receive);
        immutable ubyte[] data = result.data.dup;
        Document doc = Document(data);
        writeln("HiBON status code: ", doc.valid);
        assert(doc.valid is Document.Element.ErrorCode.NONE, "Message is not valid, not a HiBON Document");

        writefln("Received document of length: %s", doc.length);
        assert(doc.isRecord!(HiRPC.Sender), "Message is not a hirpc sender record");
        assert(doc.isRecord!(HiRPC.Receiver), "Message is not a hirpc receiver record");

        writeln(doc.toPretty);
    }

    sock.close();
}
