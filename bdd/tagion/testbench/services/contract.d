/// Test for [tagion.services.contract]_
module tagion.testbench.services.contract;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.time;
import tagion.hibon.HiBON;
import tagion.communication.HiRPC;
import tagion.utils.pretend_safe_concurrency;
import tagion.crypto.SecureNet;
import tagion.actor;
import tagion.testbench.services.actor_util;
import tagion.actor.exceptions;
import tagion.services.contract;

import std.stdio;

enum feature = Feature(
            "ContractInterface service.",
            [
        "The transaction service should be able to receive HiRPC, validate data format and protocol rules before it sends to and send to the Collector services.",
        "The HiRPC is package into a HiBON-Document in the following called doc."
]);

alias FeatureContext = Tuple!(
        TheDocumentIsNotAHiRPC, "TheDocumentIsNotAHiRPC",
        CorrectHiRPCFormatAndPermission, "CorrectHiRPCFormatAndPermission",
        CorrectHiRPCWithPermissionDenied, "CorrectHiRPCWithPermissionDenied",
        FeatureGroup*, "result"
);

@safe @Scenario("The Document is not a HiRPC",
        [])
class TheDocumentIsNotAHiRPC {
    ContractServiceHandle contract_handle;
    string contract_success;
    string contract_reject;
    this(ContractServiceHandle _contract_handle, string _success, string _reject) {
        contract_handle = _contract_handle;
        contract_success = _success; // The name of the service which successfull documents are sent to
        contract_reject = _reject; // The name of the service which rejected documents are sent to
    }

    Document doc;

    @Given("a doc with a correct document format but which is incorrect HiRPC format.")
    Document format() {
        writeln(thisTid);
        check(waitforChildren(Ctrl.ALIVE), "ContractService never alived");
        check(contract_handle.tid !is Tid.init, "Contract thread is not running");

        auto hibon = new HiBON();
        hibon["$test"] = 5;
        doc = Document(hibon);
        contract_handle.send(inputDoc(), doc);

        return result_ok;
    }

    @When("the doc should be received by the this services.")
    Document services() {
        return result_ok;
    }

    @Then("the doc should be checked that it is a correct HiRPC and if it is not it should be rejected.")
    Document rejected() {
        const receiveTuple = receiveOnlyTimeout!(RejectReason, Document);
        check(receiveTuple[0] == RejectReason.notAHiRPC,  "Did not reject for the correct reason");
        check(receiveTuple[1] == doc, "The rejected doc was not the same as was sent");
        return result_ok;
    }

    @But("the doc should not be sent to the Collector Service")
    Document collectorService() {
        return result_ok;
    }

}

@safe @Scenario("Correct HiRPC format and permission.",
        [
    "The #permission scenario can be executed with and without correct permission."
])
class CorrectHiRPCFormatAndPermission {
    ContractServiceHandle contract_handle;
    string contract_success;
    string contract_reject;
    HiRPC hirpc;
    this(ContractServiceHandle _contract_handle, string _success, string _reject) {
        contract_handle = _contract_handle;
        contract_success = _success; // The name of the service which successfull documents are sent to
        contract_reject = _reject; // The name of the service which rejected documents are sent to
        hirpc = HiRPC(new HiRPCNet("someObscurePassphrase"));
    }

    class HiRPCNet : StdSecureNet {
        this(string passphrase) {
            super();
            generateKeyPair(passphrase);
        }
    }

    Document doc;

    @Given("a correctly formatted transaction.")
    Document transaction() {
        writeln(thisTid);
        check(waitforChildren(Ctrl.ALIVE), "ContractService never alived");
        check(contract_handle.tid !is Tid.init, "Contract thread is not running");
        auto params = new HiBON;
        params["test"] = 42;
        const sender = hirpc.action(ContractMethods.transaction, params);
        doc = sender.toDoc;
        contract_handle.send(inputDoc(), doc);

        return result_ok;
    }

    // All of these are invisible to the user,
    // The test specification should be changed to reflect this
    @When("the doc package has been verified that it is correct Document.")
    Document document() {
        return result_ok;
    }

    @When("the doc package has been verified that it is correct HiRPC.")
    Document hiRPC() {
        return result_ok;
    }

    @Then("the method of HiRPC should be checked that it is \'submit\'.")
    Document submit() {
        return result_ok;
    }

    @Then("the parameter for the send to the Collector service.")
    Document service() {
        return result_ok;
    }

    @Then("if check that the Collector services received the contract.")
    Document contract() {
        const receiver = receiveOnlyTimeout!(inputHiRPC, immutable(HiRPC.Receiver))()[1];
        check(receiver.method.name == ContractMethods.transaction, "The incorrect method name was sent back");
        check(receiver.toDoc == doc, "The received sender was not the same as was sent");

        return result_ok;
    }
}

@safe @Scenario("Correct HiRPC with permission denied.",
        [])
class CorrectHiRPCWithPermissionDenied {

    ContractServiceHandle contract_handle;
    string contract_success;
    string contract_reject;
    HiRPC bad_hirpc;
    this(ContractServiceHandle _contract_handle, string _success, string _reject) {
        contract_handle = _contract_handle;
        contract_success = _success; // The name of the service which successfull documents are sent to
        contract_reject = _reject; // The name of the service which rejected documents are sent to
        bad_hirpc = HiRPC(new BadSecureNet("someLessObscurePassphrase"));
    }

    Document invalid_doc;
    @Given("a HiPRC with incorrect permission")
    Document incorrectPermission() {
        check(waitforChildren(Ctrl.ALIVE), "ContractService never alived");
        check(contract_handle.tid !is Tid.init, "Contract thread is not running");
        auto params = new HiBON;
        params["test"] = 42;
        const invalid_sender = bad_hirpc.action(ContractMethods.transaction, params);
        invalid_doc = invalid_sender.toDoc;
        contract_handle.send(inputDoc(), invalid_doc);
        return result_ok;
    }

    @When("do scenario \'#permission\'")
    Document scenarioPermission() {
        const receiveTuple = receiveOnlyTimeout!(RejectReason, Document);
        check(receiveTuple[0] == RejectReason.notSigned, "The docuemnt was not rejected for the correct reason");
        check(receiveTuple[1] == invalid_doc, "The rejected doc was not the same as was sent");
 
        return result_ok;
    }

    @Then("check that the contract is not send to the Collector.")
    Document theCollector() {
        receiveTimeout(
                Duration.zero,
                (inputHiRPC _, HiRPC.Sender __) { check(false, "Should not have received a doc"); },
        );

        contract_handle.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "Contract service Never ended");

        return result_ok;
    }

}
