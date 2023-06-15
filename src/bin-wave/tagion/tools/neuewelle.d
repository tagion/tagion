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
import core.sys.posix.signal;
import core.thread;

// enum EXAMPLES {
//     ver = Example("-v"),
//     db = Tuple("%s -d %s", program_name, file),
// }

static shared run = true;

extern (C)
void signal_handler(int _) @trusted nothrow {
    try {
        run = false;
    }
    catch (Exception e) {
        assert(0, format("DID NOT CLOSE PROPERLY \n %s", e));
    }
}

enum contract_sock_path = buildPath("/", "tmp", "tagionwave_contract.sock");

mixin Main!(_main);

int _main(string[] args) {

    sigaction_t sa;
    sa.sa_handler = &signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    // Register the signal handler for SIGINT
    sigaction(SIGINT, &sa, null);

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
    Address addr = new UnixAddress(contract_sock_path);
    Socket sock = new Socket(AddressFamily.UNIX, SocketType.STREAM);
    sock.blocking = true;
    sock.bind(addr);
    enum MAX_CONNECTIONS = 5;
    sock.listen(MAX_CONNECTIONS);

    Socket accept_sock;

    try {
        accept_sock = sock.accept;
        spawn(&echoSock, cast(immutable) accept_sock);
    }
    catch (SocketOSException e) {
        writeln("Socket was closed by os");
    }

    while (run) {
    }

    writeln("exiting");
    sock.close();

    thread_joinAll;

    forceRemove(contract_sock_path);

    return 0;
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
    // run = false;
}
