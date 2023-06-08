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
import tagion.hibon.Document;

// enum EXAMPLES {
//     ver = Example("-v"),
//     db = Tuple("%s -d %s", program_name, file),
// }

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

    const contract_sock_path = buildPath("/", "tmp", "tagionwave_contract.sock");
    scope (exit) {
        forceRemove(contract_sock_path);
    }

    writeln("contract_sock_path: ", contract_sock_path);
    Address contract_sock_addr = new UnixAddress(contract_sock_path);
    Socket contract_socket = new Socket(AddressFamily.UNIX, SocketType.STREAM);

    echoSock(contract_socket, contract_sock_addr);

    return 0;
}

void echoSock(Socket sock, Address addr) {
    bool exit = false;
    sock.bind(addr);
    sock.listen(1);
    while (!exit) {
        ReceiveBuffer buf;
        auto result = buf.append(&sock.accept.receive);
        immutable ubyte[] data = cast(immutable) result.data;
        auto doc = Document(data);
        assert(doc.valid is Document.Element.ErrorCode.NONE, "Message is not valid, not a HiBON Document");

        writefln("Received document of size: %s", doc.length);
    }

    sock.close();
}
