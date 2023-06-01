module tagion.tools.neuewelle;

// import std.stdio;
import std.format;
import std.getopt;
import tagion.tools.Basic;
import tagion.utils.getopt;
import tagion.basic.basic : forceRemove;
import core.thread;
import std.stdio;
import std.socket;
import tagion.tools.revision;
import core.sys.posix.signal;

mixin Main!(_main);

int _main(string[] args) {

    const contract_sock_path = "/tmp/tagionwave_contract.sock";
    scope(exit) {
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

    Address contract_sock_addr = new UnixAddress(contract_sock_path);
    Socket contract_socket = new Socket(AddressFamily.UNIX, SocketType.STREAM);

    echoFiber(&contract_socket, contract_sock_addr);

    return 0;
}

void echoSock(Socket *sock, Address addr) {
    bool exit = false;
    sock.bind(addr);
    sock.listen(1);
    while (!exit) {

        auto newsock = sock.accept();
        scope ubyte[1] buf;
        const bytes = newsock.receive(buf);
        writeln("Received: ", buf, bytes);
    }
    sock.close();
}
