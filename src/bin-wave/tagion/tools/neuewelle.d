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

// enum EXAMPLES {
//     ver = Example("-v"),
//     db = Tuple("%s -d %s", program_name, file),
// }

mixin Main!(_main);

int _main(string[] args) {

    const contract_sock_path = buildPath("/", "tmp", "tagionwave_contract.sock");

    version (none) static if (ver.linux || ver.FreeBSD || ver.OpenBSD || ver.DragonFlyBSD) {
        const contract_sock_path = "\0/tmp/tagionwave_contract.sock";
    }

    import tagion.basic.basic : forceRemove;

    scope (exit) {
        forceRemove(contract_sock_path);
    }

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
        writeln("Received: ", result);
    }

    sock.close();
}

ubyte[] receiveRPC(Socket sock) {
    enum MSG_PREFIX_SIZE = 4;

    scope ubyte[MSG_PREFIX_SIZE] msg_size;
    sock.handle.recv(msg_size.ptr, MSG_PREFIX_SIZE, 0);
    writeln(msg_size);
    const msg_len = msg_size.to!uint;
    scope ubyte[] msg;
    sock.handle.recv(msg.ptr, msg_len, 0);
    return msg;
}

T to(T)(ubyte[] bytes) if (isUnsigned!T && isNumeric!T)
in {
    assert(bytes.length <= T.sizeof);
}
do {
    uint value = 0;
    foreach (ubyte b; bytes) {
        value = (value << 8) + (b & 0xFF);
    }
    return value;
}
