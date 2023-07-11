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

    ~this() @trusted {
        writeln("Exit SendADocumentToTheSocket");
    }

    Address addr;
    Socket sock;
    InputValidatorHandle input_handle;
    HiBON doc;
    enum sock_path = "\0input_validator_test";
    enum some_key = "$test";
    enum some_value = 5;

    @Given("a inputvalidator")
    Document aInputvalidator() {
        register(input_test, thisTid);
        input_handle = spawn!InputValidatorService("input_test_task", "input_test", sock_path);
        check(waitfor(Ctrl.ALIVE, input_handle), "The inputvalidator did not start");
        return result_ok;
    }

    @When("we send a `Document` on a socket")
    Document aSocket() {
        addr = new UnixAddress(sock_path); // TODO: make this configurable
        sock = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        sock.blocking = false;
        doc = new HiBON();
        doc[some_key] = some_value;
        sock.connect(addr);
        check(doc.serialize.length == sock.send(doc.serialize), "The entire document was not sent");
        return result_ok;
    }

    @When("we receive back the Document in our mailbox")
    Document ourMailbox() @trusted {
        auto res = receiveOnly!(Tuple!(inputDoc, Document));
        writeln("Receive back: ", res[1].toPretty);
        check(res[1].data == doc.serialize, "The value was not the same as we sent");
        return result_ok;
    }

    @Then("stop the inputvalidator")
    Document theInputvalidator() {
        input_handle.send(Sig.STOP);
        check(waitfor(Ctrl.END, input_handle), "The inputvalidator did not stop");
        sock.close();
        return result_ok;
    }

}
