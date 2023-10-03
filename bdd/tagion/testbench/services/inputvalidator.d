/// Test for [tagion.services.inputvalidator]
module tagion.testbench.services.inputvalidator;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.actor.util;

import nngd;
import core.time;
import std.typecons;
import std.stdio;
import tagion.actor;
import tagion.actor.exceptions;
import concurrency = tagion.utils.pretend_safe_concurrency;
import tagion.services.inputvalidator;
import tagion.services.messages;
import tagion.communication.HiRPC;
import tagion.tools.Basic;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONBase;
import tagion.logger.Logger;
import tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "Inputvalidator service",
            [
        "This feature should verify that the inputvalidator accepts valid and rejects invalid LEB128 input over a socket"
]);

alias FeatureContext = Tuple!(
        SendADocumentToTheSocket, "SendADocumentToTheSocket",
        SendNoneHiRPC, "SendNoneHiRPC",
        SendPartialHiBON, "SendPartialHiBON",
        FeatureGroup*, "result"
);

@safe @Scenario("send a document to the socket", [])
class SendADocumentToTheSocket {
    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
        sock_path = _sock_path;
    }

    Document doc;

    @Given("a inputvalidator")
    Document aInputvalidator() {
        waitforChildren(Ctrl.ALIVE);
        return result_ok;
    }

    @When("we send a `Document` on a socket")
    Document aSocket() @trusted {
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        HiRPC hirpc;
        auto hibon = new HiBON();
        hibon["$test"] = 5;
        const sender = hirpc.act(hibon);
        doc = sender.toDoc;
        rc = sock.send(doc.serialize);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));

        return result_ok;
    }

    @Then("we receive back the Document in our mailbox")
    Document ourMailbox() @trusted {
        auto res = concurrency.receiveOnly!(Tuple!(inputDoc, Document));
        writeln("Receive back: ", res[1].toPretty);
        check(res[1] == doc, "The value was not the same as we sent");
        return result_ok;
    }
}

@safe @Scenario("send none hirpc document", [])
class SendNoneHiRPC {

    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
        sock_path = _sock_path;
    }

    @Given("a inputvalidator")
    Document inputvalidator() {
        waitforChildren(Ctrl.ALIVE);

        register("inputvalidator_tester", thisTid);

        log.registerSubscriptionTask("inputvalidator_tester");
        submask.subscribe(reject_inputvalidator);
        return result_ok;
    }

    @When("we send a document which is not a HiRPC on a socket")
    Document socket() @trusted {
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", rc));

        auto hibon = new HiBON();
        hibon["$test"] = 5;
        writefln("Buf lenght %s %s", hibon.serialize.length, Document(hibon.serialize).valid);

        rc = sock.send(hibon.serialize);
        check(rc == 0, format("Failed to send %s", rc));
        return result_ok;
    }

    @Then("the inputvalidator rejects")
    Document rejects() {
        import tagion.testbench.actor.util;

        check(!concurrency.receiveTimeout(100.msecs, (inputDoc _, Document __) {}), "should not have received a doc");
        const received = concurrency.receiveTimeout(100.msecs, (Topic t, string s, const(Document) d) {
            writefln("Received rejected ", d);
        });
        check(received, "Didn't received rejected");

        return result_ok;
    }

}

@safe @Scenario("send partial HiBON", [])
class SendPartialHiBON {

    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
        sock_path = _sock_path;
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
    }

    @Given("a inputvalidator")
    Document inputvalidator() {
        check(waitforChildren(Ctrl.ALIVE), "waitforChildren");

        register("inputvalidator_tester", thisTid);
        log.registerSubscriptionTask("inputvalidator_tester");
        submask.subscribe(reject_inputvalidator);
        return result_ok;
    }

    @When("we send a `partial_hibon` on a socket")
    Document socket() @trusted {
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        HiRPC hirpc;
        auto hibon = new HiBON();
        hibon["$test"] = 5;
        const sender = hirpc.act(hibon);
        Document doc = sender.toDoc;
        immutable partial_buf = doc.serialize[0 .. 26].dup;
        writefln("Buf lenght %s %s", partial_buf.length, Document(partial_buf).valid);
        rc = sock.send(partial_buf);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));
        return result_ok;
    }

    @Then("the inputvalidator rejects")
    Document rejects() {
        check(!concurrency.receiveTimeout(100.msecs, (inputDoc _, Document __) {}), "should not have received a doc");
        const received = receiveOnlyTimeout!(Topic, string, const(Document)); // Subscribed rejected data
        check(received !is typeof(received).init, "Didn't received rejected");
        return result_ok;
    }

}
