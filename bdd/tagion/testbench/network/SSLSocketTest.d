module tagion.testbench.network.SSLSocketTest;

import std.stdio;
import std.string;
import std.socket : InternetAddress, Socket, SocketException, TcpSocket, getAddress, SocketType, AddressFamily, ProtocolType, SocketShutdown, SocketSet;

import tagion.network.SSLSocket;
import stdc_io = core.stdc.stdio;
import tagion.network.SSL;
import std.concurrency;
import tagion.behaviour;
import core.thread;

@trusted
string echoSSLSocket(string address, const ushort port, string msg) {
    version (WOLFSSL) import tagion.network.wolfssl.c.ssl;

    auto buffer = new char[1024];
    auto socket = new SSLSocket(AddressFamily.INET, SocketType.STREAM); //, ProtocolType.TCP);
    auto addresses = getAddress(address, port);
    socket.connect(addresses[0]);
    writef("*");
    socket.send(msg);
    const size = socket.receive(buffer);
    socket.shutdown;
    return buffer[0 .. size].idup;
}

@trusted
void echoSSLSocketTask(
        string address,
        immutable ushort port,
        string prefix,
        immutable uint calls,

        immutable bool send_to_owner) {
    foreach (i; 0 .. calls) {
        const message = format("%s%s", prefix, i);
        const response = echoSSLSocket(address, port, message);
        check(response == message,
                format("Error: message and response not the same got: <%s>", response));
    }
    writefln("##### DONE %s\n", prefix);
    if (send_to_owner) {
        ownerTid.send(true);
    }
}

@trusted
void echoSSLSocketServer(string address, const ushort port, string cert) {
    auto server = new SSLSocket(AddressFamily.INET, SocketType.STREAM, cert);
    auto addr = getAddress(address, port);
    auto buffer = new char[1024];
    server.bind(addr[0]);
    server.listen(10);

    bool stop;
    while (!stop) {
        auto client = cast(SSLSocket) server.accept(); /* accept connection as usual */
        const size = client.receive(buffer);
        const received_buffer = buffer[0 .. size];
        SSL_write(client.ssl, buffer.ptr, cast(int) size); /* send reply */
        client.send(received_buffer);
        client.shutdown;
        stop = received_buffer == "EOC"; /* service connection */
    }
    writeln("shutdown!");
    server.shutdown(SocketShutdown.BOTH);
    server.close();
}

import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.network.ServerFiber;
import tagion.network.SSLServiceOptions;
import tagion.network.ServerAPI;

import tagion.basic.TagionExceptions : fatal;
import tagion.logger.Logger;
import tagion.basic.Types : Control;
import tagion.GlobalSignals : abort;

@safe
struct TestPackage {
    string label;
    int count;
    mixin HiBONRecord!();
}

void yield() @trusted {
    Fiber.yield;
}

bool check_doc(const Document main_doc,
        const Document.Element.ErrorCode error_code,
        const(Document.Element) current, const(Document.Element) previous) nothrow @safe {
    return false;
}

@safe
class TestRelay : ServerFiber.Relay {
    bool agent(FiberRelay relay) {
        writefln("Relay");
        immutable buffer = relay.receive;
        const doc = Document(buffer);
        check(doc.isInorder, "Invalid document");
        do {
            yield;
        }
        while (!relay.available);
        auto test_package = TestPackage(doc);
        test_package.count++;
        //            yield;
        relay.send(test_package.toDoc.serialize);
        return true;
    }
}

void testServerTask(
        immutable ServerOptions opts,
        string task_name) nothrow {
    try {
        version (none)
            scope (success) {

                ownerTid.send(Control.END);
            }
        log.register(task_name);
        bool stop;
        void handleState(Control ts) {
            with (Control) switch (ts) {
            case STOP:
                stop = true;
                break;
            default:
                log.warning("Bad Control command %s", ts);
            }
        }

        auto relay = new TestRelay;
        auto listener = new Socket(
                AddressFamily.INET,
                SocketType.STREAM);
        auto ssl_test_service = ServerAPI(
                opts,
                listener,
                relay);
        ssl_test_service.start;
        scope (exit) {
            ssl_test_service.stop;
        }
        ownerTid.send(Control.LIVE);
        while (!stop && !abort) {
            receiveTimeout(
                    500.msecs,
                    &handleState
            );
            writeln("..... running ....");
        }
    }
    catch (Throwable e) {
        fatal(e);
    }
}

void testSSLServerTask(
        immutable SSLServiceOptions ssl_options,
        string task_name) nothrow {
    try {
        log.register(task_name);
        bool stop;
        void handleState(Control ts) {
            with (Control) switch (ts) {
            case STOP:
                stop = true;
                break;
            default:
                log.warning("Bad Control command %s", ts);
            }
        }

        auto relay = new TestRelay;
        auto listener = new SSLSocket(
                AddressFamily.INET,
                SocketType.STREAM,
                ssl_options.cert.certificate,
                ssl_options.cert.private_key);
        auto ssl_test_service = ServerAPI(
                ssl_options.server,
                listener,
                relay);
        ssl_test_service.start;
        scope (exit) {
            ssl_test_service.stop;
        }
        ownerTid.send(Control.LIVE);
        while (!stop && !abort) {
            receiveTimeout(
                    500.msecs,
                    &handleState
            );
            writeln("..... running ....");
        }
    }
    catch (Throwable e) {
        fatal(e);
    }
}

void simpleSSLServer(immutable SSLServiceOptions opt, Socket listener) {

    version (none) {
        //     auto listener = new TcpSocket;
        auto add = new InternetAddress(opt.address, opt.port);
        listener.bind(add);
        pragma(msg, "FixMe(cbr): why is this value 10");
        listener.listen(10);
        auto socketSet = new SocketSet(1);

        scope (exit) {
            if (listener !is null) {
                log("Close listener socket %d", port);
                socketSet.reset;
                close;
                listener.close;
            }
        }

        while (!stop_listener) {
            socketSet.add(listener);
            pragma(msg, "FixMe(cbr): 500.msecs should be a options parameter");
            Socket.select(socketSet, null, null, timeout.msecs);
            if (socketSet.isSet(listener)) {
                try {
                    auto client = listener.accept;
                    assert(client.isAlive);
                    assert(listener.isAlive);
                    this.add(client);
                }
                catch (SocketAcceptException ex) {
                    log.error("%s", ex);
                }
            }
            socketSet.reset;
        }

    }
}
/// Check ssl
/// openssl s_client -connect 119.110.205.66:443 -showcerts
/// https://quuxplusone.github.io/blog/2020/01/28/openssl-part-5
