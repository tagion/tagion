/// Test for [tagion.services.inputvalidator]
module tagion.testbench.services.inputvalidator;
// Default import list for bdd
import core.time;
import nngd;
import std.format;
import std.stdio;
import std.typecons : Tuple;
import std.typecons;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONJSON;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.services.inputvalidator;
import tagion.services.messages;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import concurrency = tagion.utils.pretend_safe_concurrency;
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
        SendBigContract, "SendBigContract",
        FeatureGroup*, "result"
);

@safe @Scenario("send a HiRPC document to the socket", [])
class SendADocumentToTheSocket {
    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
    }

    Document doc;

    @Given("a inputvalidator")
    Document aInputvalidator() {
        waitforChildren(Ctrl.ALIVE);
        return result_ok;
    }

    @When("we send a HiRPC `Document`")
    Document aSocket() @trusted {
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
        sock.recvbuf = 4096;
        int rc = sock.dial(sock_path /* nonblock : true */ );
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        HiRPC hirpc;
        auto hibon = new HiBON();
        hibon["$test"] = 5;
        const sender = hirpc.act(hibon);
        doc = sender.toDoc;
        rc = sock.send(doc.serialize);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty doc");
        auto receiver = hirpc.receive(received);
        check(receiver.isResponse, "Expected an error");

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
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
    }

    @Given("a inputvalidator")
    Document inputvalidator() {
        waitforChildren(Ctrl.ALIVE);

        register("inputvalidator_tester", thisTid);

        log.registerSubscriptionTask("inputvalidator_tester");
        submask.subscribe(InputValidatorService.rejected);
        return result_ok;
    }

    @When("we send a document which is not a HiRPC on a socket")
    Document socket() @trusted {
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
        sock.recvbuf = 4096;
        sock.recvtimeout = msecs(1000);
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", rc));

        auto hibon = new HiBON();
        hibon["$test"] = 5;
        writefln("Buf length %s %s", hibon.serialize.length, Document(hibon.serialize).valid);

        rc = sock.send(hibon.serialize);
        check(rc == 0, format("Failed to send %s", rc));
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty buffer");
        check(received !is Document.init, "Received empty document");
        HiRPC hirpc = HiRPC(null);
        auto receiver = hirpc.receive(received);
        check(receiver.isError, "Expected an error");

        return result_ok;
    }

    @Then("the inputvalidator rejects")
    Document rejects() {
        import tagion.testbench.actor.util;

        check(!concurrency.receiveTimeout(100.msecs, (inputDoc _, Document __) {}),
                "should not have received a doc");
        receiveOnlyTimeout!(LogInfo, const(Document));

        return result_ok;
    }

}

@safe @Scenario("send partial HiBON", [])
class SendPartialHiBON {

    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 4096;
    }

    @Given("a inputvalidator")
    Document inputvalidator() {
        check(waitforChildren(Ctrl.ALIVE), "waitforChildren");

        register("inputvalidator_tester", thisTid);
        log.registerSubscriptionTask("inputvalidator_tester");
        submask.subscribe(InputValidatorService.rejected);
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
        writefln("Buf length %s %s", partial_buf.length, Document(partial_buf).valid);
        rc = sock.send(partial_buf);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty doc");
        auto receiver = hirpc.receive(received);
        check(receiver.isError, "Expected an error");

        return result_ok;
    }

    @Then("the inputvalidator rejects")
    Document rejects() {
        check(!concurrency.receiveTimeout(100.msecs, (inputDoc _, Document __) {}), "should not have received a doc");
        receiveOnlyTimeout!(LogInfo, const(Document)); // Subscribed rejected data
        return result_ok;
    }

}

@safe @Scenario("send Big Contract",
        [])
class SendBigContract {

    NNGSocket sock;
    const string sock_path;
    this(string _sock_path) @trusted {
        sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        sock_path = _sock_path;
        sock.sendtimeout = msecs(1000);
        sock.sendbuf = 0x4000;
    }


    @Given("a inputvalidator")
    Document inputvalidator() {
        check(waitforChildren(Ctrl.ALIVE), "waitforChildren");

        register("inputvalidator_tester", thisTid);
        log.registerSubscriptionTask("inputvalidator_tester");
        submask.subscribe(InputValidatorService.rejected);
        return result_ok;
    }

    @When("we send a `huge contract` on a socket")
    Document socket() @trusted {
        import std.range;
        import std.algorithm;

        HiRPC hirpc;
        int rc = sock.dial(sock_path);
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
        auto hibon = new HiBON();

        string long_string = iota(0,10_000).map!(i => format("%d", i)).join;
        // writefln(long_string);
        hibon["$test"] = long_string;
        const sender = hirpc.act(hibon);
        auto to_send = sender.toDoc.serialize;
        writefln("long_hibon length=%skb", to_send.length/1000, Document(to_send).valid);
        rc = sock.send(to_send);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));
        Document received = sock.receive!Buffer;
        check(sock.errno == 0, format("Failed to receive %s", nng_errstr(sock.errno)));
        check(received.length != 0, "Received empty doc");
        auto receiver = hirpc.receive(received);
        writefln(receiver.toPretty);
        check(!receiver.isError, "Did not expect an error");
        
        return result_ok;
    }

    @Then("we should receive response ok")
    Document ok() {
        check(concurrency.receiveTimeout(200.msecs, (inputDoc _, Document __) {}), "should have received a doc");
        return result_ok;
    }

}
