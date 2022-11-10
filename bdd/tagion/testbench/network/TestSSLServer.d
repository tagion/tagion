module tagion.testbench.network.TestSSLServer;

import core.thread.fiber;
import std.concurrency;

import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.basic.Types : Control;
import tagion.logger.Logger;
import tagion.basic.TagionExceptions : fatal;

import tagion.network.SSLFiberService;
import tagion.network.SSLServiceAPI;
import tagion.network.SSLOptions;
import tagion.network.SSLSocketException;

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
        while (!stop) {
            receive(
                    &handleState
            );
        }
    }
    catch (Throwable e) {
        fatal(e);
    }
}
