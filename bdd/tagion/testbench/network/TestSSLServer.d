module tagion.testbench.network.TestSSLServer;

import core.thread.fiber;

import tagion.hibon.Document;
import tagion.network.SSLFiberService;
import tagion.network.SSLServiceAPI;
import tagion.behaviour.BehaviourException;

void yield() @trusted {
    Fiber.yield;
}

bool check_doc(const Document main_doc,
        const Document.Element.ErrorCode error_code,
        const(Document.Element) current, const(Document.Element) previous) nothrow @safe {
    return false;
}

    version(none)
@safe
class SSLTestRelay : SSLFiberService.Relay {
    bool agent(SSLFiber ssl_relay) {
        immutable buffer = ssl_relay.receive;
        const doc = Document(buffer);
        check(doc.isInorder, "Invalid document");
        do {
            yield;
        }
        while (!ssl_relay.avaliable);

    }

}
