module tagion.testbench.services.trt_contract;

import core.thread;
import std.typecons : Tuple;
import std.algorithm.iteration;
import std.range;
import std.stdio;

import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.services.options;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.script.TagionCurrency;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.script.common;
import tagion.communication.HiRPC;
import tagion.wallet.request;
import tagion.testbench.services.helper_functions;
import tagion.crypto.SecureNet;
import tagion.dart.DARTBasic : dartIndex;
import std.digest : toHexString;
import tagion.basic.Types : encodeBase64;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum CONTRACT_TIMEOUT = 40;

enum feature = Feature(
        "TRT contract scenarios",
        []);

alias FeatureContext = Tuple!(
    ProperContract, "ProperContract",
    InvalidContract, "InvalidContract",
    FeatureGroup*, "result"
);

@safe @Scenario("Proper contract",
    [])
class ProperContract {
    Options opts1;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;

    SignedContract signed_contract;
    TagionCurrency fee;
    TagionCurrency amount;
    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    auto net = new StdHashNet;

    this(Options opts1, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;

        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("a network")
    Document network() {
        return result_ok;
    }

    @Given("a correctly signed contract")
    Document contract() {
        amount = 1000.TGN;
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract, fee)
                .value, "Error creating wallet");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");

        writeln("Contract hash: ", net.dartIndex(signed_contract.contract.toDoc).encodeBase64);

        return result_ok;
    }

    @When("the contract is sent to the network")
    Document theNetwork() {
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        sendHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit, wallet1_hirpc);
        sendHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit, wallet1_hirpc);

        return result_ok;
    }

    @When("the contract goes through")
    Document goesThrough() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();

        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.dart_interface.sock_addr, wallet1_hirpc);
        check(wallet1_amount == start_amount1 - amount - fee, "did not send money");

        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.dart_interface.sock_addr, wallet2_hirpc);
        check(wallet2_amount == start_amount2 + amount, "did not receive money");

        return result_ok;
    }

    @Then("the contract should be saved in the TRT")
    Document tRT() {
        // TBD
        return result_ok;
    }

}

@safe @Scenario("Invalid contract",
    [])
class InvalidContract {

    @Given("a network")
    Document aNetwork() {
        return result_ok;
    }

    @Given("a incorrect contract which fails in the Transcript")
    Document theTranscript() {
        return result_ok;
    }

    @When("the contract is sent to the network")
    Document theNetwork() {
        return result_ok;
    }

    @Then("it should be rejected")
    Document beRejected() {
        return result_ok;
    }

    @Then("the contract should not be stored in the TRT")
    Document theTRT() {
        return result_ok;
    }

}
