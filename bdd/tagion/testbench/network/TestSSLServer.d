module tagion.testbench.network.TestSSLServer;

import core.thread.fiber;
import core.time;
import std.concurrency;
import std.stdio;

import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.basic.Types : Control;
import tagion.logger.Logger;
import tagion.basic.TagionExceptions : fatal;
import tagion.GlobalSignals : abort;

import tagion.network.SSLFiberService;
import tagion.network.SSLServiceAPI;
import tagion.network.SSLOptions;
import tagion.network.SSLSocketException;

import std.socket;

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
class SSLTestRelay : SSLFiberService.Relay {
    bool agent(SSLFiber ssl_relay) {
        immutable buffer = ssl_relay.receive;
        const doc = Document(buffer);
        check(doc.isInorder, "Invalid document");
        do {
            yield;
        }
        while (!ssl_relay.available);
        auto test_package = TestPackage(doc);
        test_package.count++;
        //            yield;
        ssl_relay.send(test_package.toDoc.serialize);
        return true;
    }

}

void taskTestServer(
        immutable SSLOptions ssl_options,
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

        auto relay = new SSLTestRelay;
        auto ssl_test_service = SSLServiceAPI(
                ssl_options,
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

    
void simpleSSLServer(immutable SSLOptions opt, Socket listener)
{
    
version(none) {
           //     auto listener = new TcpSocket;
            auto add = new InternetAddress(opt.address, opt.port);
            listener.bind(add);
            pragma(msg, "FixMe(cbr): why is this value 10");
            listener.listen(10);
            auto socketSet = new SocketSet(1);

            scope (exit)
            {
                if (listener !is null)
                {
                    log("Close listener socket %d", port);
                    socketSet.reset;
                    close;
                    listener.close;
                }
            }

            while (!stop_listener)
            {
                socketSet.add(listener);
                pragma(msg, "FixMe(cbr): 500.msecs should be a options parameter");
                Socket.select(socketSet, null, null, timeout.msecs);
                if (socketSet.isSet(listener))
                {
                    try
                    {
                        auto client = listener.accept;
                        assert(client.isAlive);
                        assert(listener.isAlive);
                        this.add(client);
                    }
                    catch (SocketAcceptException ex)
                    {
                        log.error("%s", ex);
                    }
                }
                socketSet.reset;
            }

}
}

