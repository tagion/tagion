module tagion.testbench.services.double_spend;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.tools.wallet.WalletInterface;
import tagion.services.options;
import tagion.hibon.Document;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.execute;
import tagion.script.Currency : totalAmount;
import tagion.communication.HiRPC;
import tagion.utils.pretend_safe_concurrency : receiveOnly, receiveTimeout;
import tagion.logger.Logger;
import tagion.actor;
import tagion.testbench.actor.util;

import std.range;
import std.algorithm;
import core.time;
import core.thread;
import std.stdio;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum feature = Feature(
            "double spend scenarios",
            []);

alias FeatureContext = Tuple!(
        SameInputsSpendOnOneContract, "SameInputsSpendOnOneContract",
        OneContractWhereSomeBillsAreUsedTwice, "OneContractWhereSomeBillsAreUsedTwice",
        SameContractDifferentNodes, "SameContractDifferentNodes",
        SameContractInDifferentEpochs, "SameContractInDifferentEpochs",
        SameContractInDifferentEpochsDifferentNode, "SameContractInDifferentEpochsDifferentNode",
        TwoContractsSameOutput, "TwoContractsSameOutput",
        BillAge, "BillAge",
        AmountOnOutputBills, "AmountOnOutputBills",
        FeatureGroup*, "result"
);

@safe @Scenario("Same inputs spend on one contract",
        [])
class SameInputsSpendOnOneContract {

    Options opts;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract;

    this(Options opts, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts = opts;
    }
    import tagion.services.collector : reject_collector;

    @Given("i have a malformed contract with two inputs which are the same")
    Document same() {
        thisActor.task_name = "malformed_contract_task";
        log.registerSubscriptionTask(thisActor.task_name);

        const amount_to_pay = 1100.TGN;
        auto payment_request = wallet2.requestBill(amount_to_pay);

        auto wallet1_bill = wallet1.account.bills.front;
        check(wallet1_bill.value == 1000.TGN, "should be 1000 tgn");

        PayScript pay_script;
        pay_script.outputs = [payment_request];
        
        TagionBill[] collected_bills = [wallet1_bill, wallet1_bill];
        const fees = ContractExecution.billFees(collected_bills.length, pay_script.outputs.length+1);

        const total_collected_amount = collected_bills
            .map!(bill => bill.value)
            .totalAmount;

        const amount_remainder = total_collected_amount - amount_to_pay - fees;
        const nets = wallet1.collectNets(collected_bills);
        const bill_remain = wallet1.requestBill(amount_remainder);
        pay_script.outputs ~= bill_remain;
        wallet1.lock_bills(collected_bills);
        
        check(nets.length == collected_bills.length, format("number of bills does not match number of signatures nets %s, collected_bills %s", nets
                    .length, collected_bills.length));
        
        signed_contract = sign(
            nets,
            collected_bills.map!(bill => bill.toDoc)
            .array,
            null,
            pay_script.toDoc
        );

        check(signed_contract.contract.inputs.length == 2, "should contain two inputs");
        return result_ok;
    }

    @When("i send the contract to the network")
    Document network() {

        submask.subscribe(reject_collector);
        auto wallet1_hirpc = HiRPC(wallet1.net);
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        writefln("---SUBMIT ADDRESS--- %s", opts.inputvalidator.sock_addr); 
        sendSubmitHiRPC(opts.inputvalidator.sock_addr, hirpc_submit);

        return result_ok;
    }

    @Then("the inputs should be deleted from the dart.")
    Document dart() {
        auto result = receiveOnlyTimeout!(Topic, string, const(Document));
        check(result[1] == "missing_archives", "did not reject for the expected reason");
        submask.unsubscribe(reject_collector);
        return result_ok;
    }

}

@safe @Scenario("one contract where some bills are used twice.",
        [])
class OneContractWhereSomeBillsAreUsedTwice {
    Options opts;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract;

    this(Options opts, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts = opts;
    }

    import tagion.services.collector : reject_collector;
    @Given("i have a malformed contract with three inputs where to are the same.")
    Document same() {
        const amount_to_pay = 2500.TGN;
        auto payment_request = wallet2.requestBill(amount_to_pay);

        auto wallet1_bill = wallet1.account.bills[0];
        auto wallet2_bill = wallet1.account.bills[1];
        check(wallet1_bill.value == 1000.TGN, "should be 1000 tgn");
        check(wallet2_bill.value == 1000.TGN, "should be 1000 tgn");

        PayScript pay_script;
        pay_script.outputs = [payment_request];
        
        TagionBill[] collected_bills = [wallet1_bill, wallet1_bill, wallet2_bill];
        const fees = ContractExecution.billFees(collected_bills.length, pay_script.outputs.length+1);

        const total_collected_amount = collected_bills
            .map!(bill => bill.value)
            .totalAmount;

        const amount_remainder = total_collected_amount - amount_to_pay - fees;
        const nets = wallet1.collectNets(collected_bills);
        const bill_remain = wallet1.requestBill(amount_remainder);
        pay_script.outputs ~= bill_remain;
        wallet1.lock_bills(collected_bills);
        
        check(nets.length == collected_bills.length, format("number of bills does not match number of signatures nets %s, collected_bills %s", nets
                    .length, collected_bills.length));
        
        signed_contract = sign(
            nets,
            collected_bills.map!(bill => bill.toDoc)
            .array,
            null,
            pay_script.toDoc
        );

        check(signed_contract.contract.inputs.length == 3, "should contain two inputs");
        check(signed_contract.contract.inputs.uniq.array.length == 2, "should be malformed and contain two identical and one different bill");
        return result_ok;
    }

    @When("i send the contract to the network")
    Document network() {
        submask.subscribe(reject_collector);
        auto wallet1_hirpc = HiRPC(wallet1.net);
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        writefln("---SUBMIT ADDRESS--- %s", opts.inputvalidator.sock_addr); 
        sendSubmitHiRPC(opts.inputvalidator.sock_addr, hirpc_submit);

        return result_ok;
    }

    @Then("all the inputs should be deleted from the dart.")
    Document dart() {
        auto result = receiveOnlyTimeout!(Topic, string, const(Document));
        check(result[1] == "missing_archives", "did not reject for the expected reason");
        submask.unsubscribe(reject_collector);
        return result_ok;
    }

}

@safe @Scenario("Same contract different nodes.",
        [])
class SameContractDifferentNodes {

    @Given("i have a correctly signed contract.")
    Document contract() {
        return Document();
    }

    @When("i send the same contract to two different nodes.")
    Document nodes() {
        return Document();
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Same contract in different epochs.",
        [])
class SameContractInDifferentEpochs {

    @Given("i have a correctly signed contract.")
    Document contract() {
        return Document();
    }

    @When("i send the contract to the network in different epochs to the same node.")
    Document node() {
        return Document();
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Same contract in different epochs different node.",
        [])
class SameContractInDifferentEpochsDifferentNode {

    @Given("i have a correctly signed contract.")
    Document contract() {
        return Document();
    }

    @When("i send the contract to the network in different epochs to different nodes.")
    Document nodes() {
        return Document();
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Two contracts same output",
        [])
class TwoContractsSameOutput {

    @Given("i have a payment request containing a bill.")
    Document bill() {
        return Document();
    }

    @When("i pay the bill from two different wallets.")
    Document wallets() {
        return Document();
    }

    @Then("only one output should be produced.")
    Document produced() {
        return Document();
    }

}

@safe @Scenario("Bill age",
        [])
class BillAge {

    @Given("i pay a contract where the output bills timestamp is newer than epoch_time + constant.")
    Document constant() {
        return Document();
    }

    @When("i send the contract to the network.")
    Document network() {
        return Document();
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Amount on output bills",
        [])
class AmountOnOutputBills {

    @Given("i create a contract with outputs bills that are smaller or equal to zero.")
    Document zero() {
        return Document();
    }

    @When("i send the contract to the network.")
    Document network() {
        return Document();
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        return Document();
    }

}
