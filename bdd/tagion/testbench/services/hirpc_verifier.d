/// Test for [tagion.services.hirpc_verifier]_
module tagion.testbench.services.hirpc_verifier;
// Default import list for bdd
import core.time;
import std.stdio;
import std.typecons : Tuple;
import std.algorithm;
import std.range;

import tagion.actor;
import tagion.actor.exceptions;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.services.hirpc_verifier;
import tagion.services.messages;
import tagion.services.codes;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.utils.pretend_safe_concurrency;
import tagion.script.TagionCurrency;
import tagion.script.common;

enum feature = Feature(
            "HiRPCInterfaceService.",
            [
        "The transaction service should be able to receive HiRPC, validate data format and protocol rules before it sends to and send to the Collector services.",
        "The HiRPC is package into a HiBON-Document in the following called doc."
]);

alias FeatureContext = Tuple!(
        TheDocumentIsNotAHiRPC, "TheDocumentIsNotAHiRPC",
        CorrectHiRPCFormatAndPermission, "CorrectHiRPCFormatAndPermission",
        CorrectHiRPCWithPermissionDenied, "CorrectHiRPCWithPermissionDenied",
        HIRPCWithIllegalMethod, "HIRPCWithIllegalMethod",
        FeatureGroup*, "result"
);

@safe @Scenario("The Document is not a HiRPC",
        [])
class TheDocumentIsNotAHiRPC {
    ActorHandle hirpc_verifier_handle;
    string hirpc_verifier_success;
    string hirpc_verifier_reject;
    this(ActorHandle _hirpc_verifier_handle, string _success, string _reject) {
        hirpc_verifier_handle = _hirpc_verifier_handle;
        hirpc_verifier_success = _success; // The name of the service which successful documents are sent to
        hirpc_verifier_reject = _reject; // The name of the service which rejected documents are sent to
    }

    Document doc;

    @Given("a doc with a correct document format but which is incorrect HiRPC format.")
    Document format() {
        writeln(thisTid);
        check(waitforChildren(Ctrl.ALIVE), "hirpc_verifierService never alived");
        check(hirpc_verifier_handle.tid !is Tid.init, "hirpc_verifier thread is not running");

        auto hibon = new HiBON();
        hibon["$test"] = 5;
        doc = Document(hibon);
        hirpc_verifier_handle.send(inputDoc(), doc);

        return result_ok;
    }

    @When("the doc should be received by the this services.")
    Document services() {
        return result_ok;
    }

    @Then("the doc should be checked that it is a correct HiRPC and if it is not it should be rejected.")
    Document rejected() {
        const receiveTuple = receiveOnlyTimeout!(ServiceCode, Document);
        check(receiveTuple[0] == ServiceCode.hirpc, "Did not reject for the correct reason");
        check(receiveTuple[1] == doc, "The rejected doc was not the same as was sent");
        return result_ok;
    }

    @But("the doc should not be sent to the Collector Service")
    Document collectorService() {
        return result_ok;
    }

}

SignedContract create_dummy_signed_contract() @safe {
    import std.array;
    import tagion.basic.Types : Buffer;
    import tagion.crypto.Types;
    import tagion.utils.StdTime;

    Document[] in_bills;
    in_bills ~= iota(0, 10).map!(_ => TagionBill(10.TGN, sdt_t.init, Pubkey.init, Buffer.init).toDoc).array;
    immutable(TagionBill)[] out_bills;
    out_bills ~= iota(0, 10).map!(_ => TagionBill(5.TGN, sdt_t.init, Pubkey.init, Buffer.init)).array;
    auto contract = immutable(Contract)(null, null, PayScript(out_bills).toDoc);
    SignedContract signed_contract = SignedContract(null, contract);

    return signed_contract;
}

@safe @Scenario("Correct HiRPC format and permission.",
        [
    "The #permission scenario can be executed with and without correct permission."
])
class CorrectHiRPCFormatAndPermission {
    ActorHandle hirpc_verifier_handle;
    string contract_success;
    string contract_reject;
    HiRPC hirpc;
    this(ActorHandle _hirpc_verifier_handle, string _success, string _reject) {
        hirpc_verifier_handle = _hirpc_verifier_handle;
        contract_success = _success; // The name of the service which successful documents are sent to
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
        check(hirpc_verifier_handle.tid !is Tid.init, "Contract thread is not running");

        auto signed_contract = create_dummy_signed_contract();

        const sender = hirpc.submit(signed_contract);
        doc = sender.toDoc;
        hirpc_verifier_handle.send(inputDoc(), doc);

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
        check(receiver.method.name == ContractMethods.submit, "The incorrect method name was sent back");
        check(receiver.toDoc == doc, "The received sender was not the same as was sent");

        return result_ok;
    }
}

@safe @Scenario("Correct HiRPC with permission denied.",
        [])
class CorrectHiRPCWithPermissionDenied {

    ActorHandle hirpc_verifier_handle;
    string hirpc_verifier_success;
    string hirpc_verifier_reject;
    HiRPC bad_hirpc;
    this(ActorHandle _hirpc_verifier_handle, string _success, string _reject) {
        hirpc_verifier_handle = _hirpc_verifier_handle;
        hirpc_verifier_success = _success; // The name of the service which successful documents are sent to
        hirpc_verifier_reject = _reject; // The name of the service which rejected documents are sent to
        bad_hirpc = HiRPC(null);
    }

    Document invalid_doc;
    @Given("a HiPRC with incorrect permission")
    Document incorrectPermission() {
        check(waitforChildren(Ctrl.ALIVE), "hirpc_verifierService never alived");
        check(hirpc_verifier_handle.tid !is Tid.init, "hirpc_verifier thread is not running");

        auto signed_contract = create_dummy_signed_contract();

        const invalid_sender = bad_hirpc.action(ContractMethods.submit, signed_contract);
        invalid_doc = invalid_sender.toDoc;
        hirpc_verifier_handle.send(inputDoc(), invalid_doc);
        return result_ok;
    }

    @When("do scenario \'#permission\'")
    Document scenarioPermission() {
        const receiveTuple = receiveOnlyTimeout!(ServiceCode, Document);
        check(receiveTuple[0] == ServiceCode.sign, "The document was not rejected for the expected reason : " ~ receiveTuple[0]
                .toString);
        check(receiveTuple[1] == invalid_doc, "The rejected doc was not the same as was sent");

        return result_ok;
    }

    @Then("check that the contract is not send to the Collector.")
    Document theCollector() {
        receiveTimeout(
                Duration.zero,
                (inputHiRPC _, HiRPC.Sender __) { check(false, "Should not have received a doc"); },
        );

        return result_ok;
    }

}

@safe @Scenario("A hirpc with an illegal type", [])
class HIRPCWithIllegalMethod {
    ActorHandle hirpc_verifier_handle;
    string contract_success;
    string contract_reject;
    HiRPC hirpc;
    SecureNet net;
    this(ActorHandle _hirpc_verifier_handle, string _success, string _reject) {
        hirpc_verifier_handle = _hirpc_verifier_handle;
        contract_success = _success; // The name of the service which successful documents are sent to
        contract_reject = _reject; // The name of the service which rejected documents are sent to

        net = new HiRPCNet("someObscurePassphrase");
        hirpc = HiRPC(net);
    }

    class HiRPCNet : StdSecureNet {
        this(string passphrase) {
            super();
            generateKeyPair(passphrase);
        }
    }

    Document invalid_doc;

    @Given("i send HiRPC submit with a non SignedContract Document")
    Document transaction() {
        import std.algorithm : map;
        import std.array;
        import std.range : iota;
        import tagion.basic.Types : Buffer;
        import tagion.crypto.Types;
        import tagion.script.TagionCurrency;
        import tagion.script.common;
        import tagion.utils.StdTime;

        writeln(thisTid);
        check(waitforChildren(Ctrl.ALIVE), "ContractService never alived");
        check(hirpc_verifier_handle.tid !is Tid.init, "Contract thread is not running");

        const signed_contract = create_dummy_signed_contract();
        const sender = hirpc.submit(signed_contract);

        HiBON hibon = new HiBON;
        hibon["a"] = 42;

        const result = hirpc.submit(hibon);
        invalid_doc = result.toDoc;

        hirpc_verifier_handle.send(inputDoc(), invalid_doc);

        return result_ok;
    }

    @Then("Then it should be rejected")
    Document contract() {
        receiveTimeout(
                Duration.zero,
                (inputHiRPC _, HiRPC.Sender __) { check(false, "Should not have received a doc"); },
        );

        const receiveTuple = receiveOnlyTimeout!(ServiceCode, Document);
        check(receiveTuple[0] == ServiceCode.params, "The document was not rejected for the expected reason : " ~ receiveTuple[0]
                .toString);
        check(receiveTuple[1] == invalid_doc, "The rejected doc was not the same as was sent");

        hirpc_verifier_handle.send(Sig.STOP);
        check(waitforChildren(Ctrl.END), "hirpc verifier service Never ended");

        return result_ok;
    }
}
