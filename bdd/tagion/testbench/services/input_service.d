module tagion.testbench.services.input_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.socket;
import std.typecons;
import std.stdio;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.utils.pretend_safe_concurrency;
import tagion.services.inputvalidator;
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
        FeatureGroup*, "result"
);

enum input_test = "input_test";

@safe @Scenario("send a document to the socket",
        [])
class SendADocumentToTheSocket {
    Address addr;
    Socket sock;
    InputValidatorHandle input_handle;
    Document doc;
    enum sock_path = "\0input_validator_test";

    @Given("a inputvalidator")
    Document aInputvalidator() {
        register(input_test, thisTid);
        input_handle = spawn!InputValidatorService("input_test_task", "input_test", sock_path);
        check(waitforChildren(Ctrl.ALIVE), "The inputvalidator did not start");
        return result_ok;
    }

    @When("we send a `Document` on a socket")
    Document aSocket() {
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
        return result_ok;
    }

    @When("we receive back the Document in our mailbox")
    Document ourMailbox() @trusted {
        auto res = receiveOnly!(Tuple!(inputDoc, Document));
        writeln("Receive back: ", res[1].toPretty);
        check(res[1] == doc, "The value was not the same as we sent");
        return result_ok;
    }

    @Then("stop the inputvalidator")
    Document theInputvalidator() {
        sock.close();
        input_handle.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "The inputvalidator did not stop");
        return result_ok;
    }

}
