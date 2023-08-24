/// Test for [tagion.services.inputvalidator]
module tagion.testbench.services.inputvalidator;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

version (NNG_INPUT) import nngd;
import std.socket;
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

enum feature = Feature(
            "Inputvalidator service",
            [
        "This feature should verify that the inputvalidator accepts valid and rejects invalid LEB128 input over a socket"
]);

alias FeatureContext = Tuple!(
        SendADocumentToTheSocket, "SendADocumentToTheSocket",
        SendRandomBuffer, "SendRandomBuffer",
        SendMalformedHiBON, "SendMalformedHiBON",
        SendPartialHiBON, "SendPartialHiBON",
        FeatureGroup*, "result"
);

enum input_test = "input_test";

@safe @Scenario("send a document to the socket",
        [])
class SendADocumentToTheSocket {
    InputValidatorHandle input_handle;
    Document doc;
    version (NNG_INPUT) {
        enum sock_path = "abstract://" ~ __MODULE__;
        NNGSocket sock;
        this() @trusted {
            sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
        }
    }
    else {
        Socket sock;
        Address addr;
        enum sock_path = "\0" ~ __MODULE__;
    }

    @Given("a inputvalidator")
    Document aInputvalidator() {
        concurrency.register(input_test, concurrency.thisTid);
        immutable opts = InputValidatorOptions(sock_path);
        input_handle = spawn!InputValidatorService("input_test_task", opts, input_test);
        check(waitforChildren(Ctrl.ALIVE), "The inputvalidator did not start");
        return result_ok;
    }

    @When("we send a `Document` on a socket")
    Document aSocket() @trusted {
        version (NNG_INPUT) {
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

        }
        else {
            addr = new UnixAddress(sock_path); // TODO: make this configurable
            sock = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            sock.blocking = false;
            HiRPC hirpc;
            auto hibon = new HiBON();
            hibon["$test"] = 5;
            const sender = hirpc.act(hibon);
            doc = sender.toDoc;
            sock.connect(addr);
            check(doc.serialize.length == sock.send(doc.serialize), "The entire document was not sent");
        }
        return result_ok;
    }

    @When("we receive back the Document in our mailbox")
    Document ourMailbox() @trusted {
        auto res = concurrency.receiveOnly!(Tuple!(inputDoc, Document));
        writeln("Receive back: ", res[1].toPretty);
        check(res[1] == doc, "The value was not the same as we sent");
        return result_ok;
    }

    @Then("stop the inputvalidator")
    Document theInputvalidator() {
        version (NNG_INPUT) {
        }
        else {
            sock.close();
        }

        input_handle.send(Sig.STOP);
        import core.time;

        check(waitforChildren(Ctrl.END, 5.seconds), "The inputvalidator did not stop");
        return result_ok;
    }
}

@safe @Scenario("send random buffer",
        [])
class SendRandomBuffer {

    @Given("a inputvalidator")
    Document inputvalidator() {
        return Document();
    }

    @When("we send a `random_buffer` on a socket")
    Document socket() {
        return Document();
    }

    @Then("the inputvalidator rejects")
    Document rejects() {
        return Document();
    }

}

@safe @Scenario("send malformed HiBON",
        [])
class SendMalformedHiBON {

    @Given("a inputvalidator")
    Document inputvalidator() {
        return Document();
    }

    @When("we send a `malformed_hibon` on a socket")
    Document socket() {
        return Document();
    }

    @Then("the inputvalidator rejects")
    Document rejects() {
        return Document();
    }

}

@safe @Scenario("send partial HiBON",
        [])
class SendPartialHiBON {

    @Given("a inputvalidator")
    Document inputvalidator() {
        return Document();
    }

    @When("we send a `partial_hibon` on a socket")
    Document socket() {
        return Document();
    }

    @Then("the inputvalidator rejects")
    Document rejects() {
        return Document();
    }

}
