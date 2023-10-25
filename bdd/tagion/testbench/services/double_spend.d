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
import tagion.utils.pretend_safe_concurrency : register, receiveOnly, receiveTimeout;
import std.concurrency : thisTid;
import tagion.logger.Logger;
import tagion.logger.LogRecords : LogInfo;
import tagion.actor;
import tagion.testbench.actor.util;
import tagion.dart.DARTcrud;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.hashgraph.Refinement;

import std.range;
import std.algorithm;
import core.time;
import core.thread;
import std.stdio;
import std.format;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum CONTRACT_TIMEOUT = 25.seconds;

enum feature = Feature(
            "double spend scenarios",
            []);

alias FeatureContext = Tuple!(
        SameInputsSpendOnOneContract, "SameInputsSpendOnOneContract",
        OneContractWhereSomeBillsAreUsedTwice, "OneContractWhereSomeBillsAreUsedTwice",
        DifferentContractsDifferentNodes, "DifferentContractsDifferentNodes",
        SameContractDifferentNodes, "SameContractDifferentNodes",
        SameContractInDifferentEpochs, "SameContractInDifferentEpochs",
        SameContractInDifferentEpochsDifferentNode, "SameContractInDifferentEpochsDifferentNode",
        TwoContractsSameOutput, "TwoContractsSameOutput",
        BillAge, "BillAge",
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

    @Given("i have a malformed contract correctly signed with two inputs which are the same")
    Document same() {



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
        sendSubmitHiRPC(opts.inputvalidator.sock_addr, hirpc_submit, wallet1.net);

        return result_ok;
    }
    @Then("the contract should be rejected.")
    Document dart() {
        auto result = receiveOnlyTimeout!(LogInfo, const(Document));
        check(result[0].symbol_name == "missing_archives", format("did not reject for the expected reason %s", result[0].symbol_name));
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
    @Given("i have a malformed contract correctly signed with three inputs where to are the same.")
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
        sendSubmitHiRPC(opts.inputvalidator.sock_addr, hirpc_submit, wallet1.net);

        return result_ok;
    }
    @Then("the contract should be rejected.")
    Document dart() {
        auto result = receiveOnlyTimeout!(LogInfo, const(Document));
        check(result[0].symbol_name== "missing_archives", format("did not reject for the expected reason %s", result[0].symbol_name));
        submask.unsubscribe(reject_collector);
        return result_ok;
    }

}

@safe @Scenario("Different contracts different nodes.",
        [])
class DifferentContractsDifferentNodes {
    Options opts1;
    Options opts2;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract1;
    SignedContract signed_contract2;
    TagionCurrency amount;
    TagionCurrency fee;

    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    this(Options opts1, Options opts2, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;
        this.opts2 = opts2;

        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
        
    }
    @Given("i have two correctly signed contracts.")
    Document contracts() {

        amount = 100.TGN;
        auto payment_request1 = wallet1.requestBill(amount);
        auto payment_request2 = wallet2.requestBill(amount);


        check(wallet1.createPayment([payment_request2], signed_contract1, fee).value, "Error creating payment wallet");

        check(wallet2.createPayment([payment_request1], signed_contract2, fee).value, "Error creating payment wallet");
        return result_ok;
    }

    @When("i send the contracts to the network at the same time.")
    Document time() {
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract1), wallet1.net);
        sendSubmitHiRPC(opts2.inputvalidator.sock_addr, wallet2_hirpc.submit(signed_contract2), wallet2.net);
        return result_ok;
    }

    @Then("both contracts should go through.")
    Document through() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT))();

        auto wallet1_dartcheckread = wallet1.getRequestCheckWallet(wallet1_hirpc);
        auto wallet1_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet1_dartcheckread);

        writefln("RECEIVED RESPONSE: %s", wallet1_received_doc.toPretty);
        auto wallet1_received = wallet1_hirpc.receive(wallet1_received_doc);
        check(wallet1.setResponseCheckRead(wallet1_received), "wallet1 not updated succesfully");

        auto wallet1_amount = wallet1.calcTotal(wallet1.account.bills);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        check(wallet1_amount == start_amount1 - fee, "did not receive tx");

        auto wallet2_dartcheckread = wallet2.getRequestCheckWallet(wallet2_hirpc);
        auto wallet2_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet2_dartcheckread);

        writefln("RECEIVED RESPONSE: %s", wallet2_received_doc.toPretty);
        auto wallet2_received = wallet2_hirpc.receive(wallet2_received_doc);
        check(wallet2.setResponseCheckRead(wallet2_received), "wallet2 not updated succesfully");
        
        auto wallet2_amount = wallet1.calcTotal(wallet1.account.bills);
        writefln("WALLET 2 amount: %s", wallet2_amount);
        check(wallet2_amount == start_amount2 - fee, "did not receive tx");
        return result_ok;
    }
}


@safe @Scenario("Same contract different nodes.",
        [])
class SameContractDifferentNodes {
    Options opts1;
    Options opts2;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract;
    TagionCurrency amount;
    TagionCurrency fee;

    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    this(Options opts1, Options opts2, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;
        this.opts2 = opts2;
        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("i have a correctly signed contract.")
    Document contract() {

        
        writefln("SAME CONTRACT DIFFERENT NODES");
        amount = 1500.TGN;
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating wallet");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");

        return result_ok;
    }

    @When("i send the same contract to two different nodes.")
    Document nodes() {
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit,wallet1.net);
        sendSubmitHiRPC(opts2.inputvalidator.sock_addr, hirpc_submit,wallet1.net);

        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT))();
        return result_ok;
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        auto wallet1_dartcheckread = wallet1.getRequestCheckWallet(wallet1_hirpc);
        auto wallet1_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet1_dartcheckread);

        // writefln("RECEIVED RESPONSE: %s", wallet1_received_doc.toPretty);
        auto wallet1_received = wallet1_hirpc.receive(wallet1_received_doc);
        check(wallet1.setResponseCheckRead(wallet1_received), "wallet1 not updated succesfully");

        auto wallet1_amount = wallet1.calcTotal(wallet1.account.bills);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        check(wallet1_amount == start_amount1-amount-fee, "wallet 1 did not lose correct amount of money");

        auto wallet2_dartcheckread = wallet2.getRequestCheckWallet(wallet2_hirpc);
        auto wallet2_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet2_dartcheckread);

        // writefln("RECEIVED RESPONSE: %s", wallet2_received_doc.toPretty);
        auto wallet2_received = wallet2_hirpc.receive(wallet2_received_doc);
        check(wallet2.setResponseCheckRead(wallet2_received), "wallet2 not updated succesfully");
        
        auto wallet2_amount = wallet2.calcTotal(wallet2.account.bills);
        writefln("WALLET 2 amount: %s", wallet2_amount);
        check(wallet2_amount == start_amount2+amount, "did not receive money");
        return result_ok;
    }

}

@safe @Scenario("Same contract in different epochs.",
        [])
class SameContractInDifferentEpochs {

    Options opts1;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract;
    TagionCurrency amount;
    TagionCurrency fee;

    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    this(Options opts1, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;
        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }
    @Given("i have a correctly signed contract.")
    Document contract() {
        submask.subscribe(StdRefinement.epoch_created);

        writefln("SAME CONTRACT different epoch");
        amount = 1500.TGN;
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating wallet");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");

        return result_ok;
    }

    @When("i send the contract to the network in different epochs to the same node.")
    Document node() {
        import tagion.hashgraph.Refinement : FinishedEpoch;

        int epoch_number;
        uint max_tries = 20;
        uint counter;
        do {
            auto epoch_before = receiveOnlyTimeout!(LogInfo, const(Document))(10.seconds);
            writefln("epoch_before %s looking for %s", epoch_before[1], opts1.task_names.epoch_creator);
            check(epoch_before[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (epoch_before[0].task_name == opts1.task_names.epoch_creator) {
                writefln("################### CAME IN ################");
                epoch_number = FinishedEpoch(epoch_before[1]).epoch;
            }
            counter++;
        } while(counter < max_tries && epoch_number is int.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        writefln("EPOCH NUMBER %s", epoch_number);

        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit,wallet1.net);

        int new_epoch_number;
        counter = 0;
        do {
            auto new_epoch = receiveOnlyTimeout!(LogInfo, const(Document))(10.seconds);
            writefln("new_epoch %s %s", new_epoch[0].topic_name, opts1.task_names.epoch_creator);
            check(new_epoch[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (new_epoch[0].task_name == opts1.task_names.epoch_creator) {
                writefln("UPDATING NEW EPOCH_NUMBER");
                new_epoch_number = FinishedEpoch(new_epoch[1]).epoch;
            }
            counter++;
        } while(counter < max_tries && new_epoch_number is int.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        writefln("EPOCH NUMBER updated %s", new_epoch_number);
        check(epoch_number < new_epoch_number, "epoch number not updated");
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit, wallet1.net);
        
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT))();
        return result_ok;
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        auto wallet1_dartcheckread = wallet1.getRequestCheckWallet(wallet1_hirpc);
        auto wallet1_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet1_dartcheckread);
        auto wallet1_received = wallet1_hirpc.receive(wallet1_received_doc);
        check(wallet1.setResponseCheckRead(wallet1_received), "wallet1 not updated succesfully");

        auto wallet2_dartcheckread = wallet2.getRequestCheckWallet(wallet2_hirpc);
        auto wallet2_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet2_dartcheckread);
        auto wallet2_received = wallet2_hirpc.receive(wallet2_received_doc);
        check(wallet2.setResponseCheckRead(wallet2_received), "wallet2 not updated succesfully");
        
        auto wallet1_amount = wallet1.calcTotal(wallet1.account.bills);
        auto wallet2_amount = wallet2.calcTotal(wallet2.account.bills);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        writefln("WALLET 2 amount: %s", wallet2_amount);

        const expected_amount1 = start_amount1-amount-fee;
        const expected_amount2 = start_amount2 + amount;
        check(wallet1_amount == expected_amount1, format("wallet 1 did not lose correct amount of money should have %s had %s", expected_amount1, wallet1_amount));
        check(wallet2_amount == expected_amount2, format("wallet 2 did not lose correct amount of money should have %s had %s", expected_amount2, wallet2_amount));


        return result_ok;
    }

}

@safe @Scenario("Same contract in different epochs different node.",
        [])
class SameContractInDifferentEpochsDifferentNode {
    Options opts1;
    Options opts2;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract;
    TagionCurrency amount;
    TagionCurrency fee;

    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    this(Options opts1,Options opts2, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;
        this.opts2 = opts2;
        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("i have a correctly signed contract.")
    Document contract() {
        submask.subscribe(StdRefinement.epoch_created);

        writefln("SAME CONTRACT different node different epoch");
        amount = 1500.TGN;
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating payment");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");

        return result_ok;
    }

    @When("i send the contract to the network in different epochs to different nodes.")
    Document nodes() {
        import tagion.hashgraph.Refinement : FinishedEpoch;
        uint max_tries = 20;
        uint counter;

        int epoch_number;
        do {
            auto epoch_before = receiveOnlyTimeout!(LogInfo, const(Document))(10.seconds);
            writefln("epoch_before %s looking for %s", epoch_before[1], opts1.task_names.epoch_creator);
            check(epoch_before[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (epoch_before[0].task_name == opts1.task_names.epoch_creator) {
                epoch_number = FinishedEpoch(epoch_before[1]).epoch;
            }
            counter++;
        } while(counter < max_tries && epoch_number is int.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        writeln("EPOCH NUMBER %s", epoch_number);

        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit, wallet1.net);

        int new_epoch_number;
        counter = 0;
        do {
            auto new_epoch = receiveOnlyTimeout!(LogInfo, const(Document))(10.seconds);
            writefln("new_epoch %s %s", new_epoch[1], opts1.task_names.epoch_creator);
            check(new_epoch[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (new_epoch[0].task_name == opts2.task_names.epoch_creator) {
                writefln("UPDATING NEW EPOCH_NUMBER");
                int _new_epoch_number = FinishedEpoch(new_epoch[1]).epoch;
                if (_new_epoch_number > epoch_number) {
                    new_epoch_number = _new_epoch_number;
                }
            }
            counter++;
        } while(counter < max_tries && new_epoch_number is int.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        writeln("EPOCH NUMBER updated %s", new_epoch_number);
        sendSubmitHiRPC(opts2.inputvalidator.sock_addr, hirpc_submit, wallet1.net);
        
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT))();
        return result_ok;
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        auto wallet1_dartcheckread = wallet1.getRequestCheckWallet(wallet1_hirpc);
        auto wallet1_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet1_dartcheckread);
        auto wallet1_received = wallet1_hirpc.receive(wallet1_received_doc);
        check(wallet1.setResponseCheckRead(wallet1_received), "wallet1 not updated succesfully");

        auto wallet2_dartcheckread = wallet2.getRequestCheckWallet(wallet2_hirpc);
        auto wallet2_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet2_dartcheckread);
        auto wallet2_received = wallet2_hirpc.receive(wallet2_received_doc);
        check(wallet2.setResponseCheckRead(wallet2_received), "wallet2 not updated succesfully");
        
        auto wallet1_amount = wallet1.calcTotal(wallet1.account.bills);
        auto wallet2_amount = wallet2.calcTotal(wallet2.account.bills);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        writefln("WALLET 2 amount: %s", wallet2_amount);

        const expected_amount1 = start_amount1-amount-fee;
        const expected_amount2 = start_amount2 + amount;
        check(wallet1_amount == expected_amount1, format("wallet 1 did not lose correct amount of money should have %s had %s", expected_amount1, wallet1_amount));
        check(wallet2_amount == expected_amount2, format("wallet 2 did not lose correct amount of money should have %s had %s", expected_amount2, wallet2_amount));

        submask.unsubscribe(StdRefinement.epoch_created);

        return result_ok;
    }

}

@safe @Scenario("Two contracts same output",
        [])
class TwoContractsSameOutput {
    Options opts1;
    Options opts2;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    StdSecureWallet wallet3;
    //
    SignedContract signed_contract1;
    SignedContract signed_contract2;
    TagionCurrency amount;
    TagionCurrency fee;

    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    HiRPC wallet3_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;
    TagionCurrency start_amount3;

    this(Options opts1,Options opts2, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2, ref StdSecureWallet wallet3) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.wallet3 = wallet3;
        this.opts1 = opts1;
        this.opts2 = opts2;
        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        wallet3_hirpc = HiRPC(wallet3.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
        start_amount3 = wallet3.calcTotal(wallet3.account.bills);
    }

    @Given("i have a payment request containing a bill.")
    Document bill() {
        amount = 333.TGN;
        auto payment_request = wallet3.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract1, fee).value, "Error paying wallet");
        check(wallet2.createPayment([payment_request], signed_contract2, fee).value, "Error paying wallet");

        check(signed_contract1.contract.inputs.uniq.array.length == signed_contract1.contract.inputs.length, "signed contract inputs invalid");
        check(signed_contract2.contract.inputs.uniq.array.length == signed_contract2.contract.inputs.length, "signed contract inputs invalid");

        return result_ok;
    }

    @When("i pay the bill from two different wallets.")
    Document wallets() {
        auto hirpc_submit1 = wallet1_hirpc.submit(signed_contract1);
        auto hirpc_submit2 = wallet2_hirpc.submit(signed_contract2);
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit1, wallet1.net);
        sendSubmitHiRPC(opts2.inputvalidator.sock_addr, hirpc_submit2, wallet2.net);


        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT))();
        return result_ok;
    }

    @Then("only one output should be produced.")
    Document produced() {
        auto wallet1_dartcheckread = wallet1.getRequestCheckWallet(wallet1_hirpc);
        auto wallet1_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet1_dartcheckread);

        // writefln("RECEIVED RESPONSE: %s", wallet1_received_doc.toPretty);
        auto wallet1_received = wallet1_hirpc.receive(wallet1_received_doc);
        check(wallet1.setResponseCheckRead(wallet1_received), "wallet1 not updated succesfully");

        auto wallet1_amount = wallet1.calcTotal(wallet1.account.bills);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        check(wallet1_amount == start_amount1-amount-fee, "wallet 1 did not lose correct amount of money");

        auto wallet2_dartcheckread = wallet2.getRequestCheckWallet(wallet2_hirpc);
        auto wallet2_received_doc = sendDARTHiRPC(opts2.dart_interface.sock_addr, wallet2_dartcheckread);

        auto wallet2_received = wallet2_hirpc.receive(wallet2_received_doc);
        check(wallet2.setResponseCheckRead(wallet2_received), "wallet2 not updated succesfully");

        auto wallet2_amount = wallet2.calcTotal(wallet2.account.bills);
        writefln("WALLET 2 amount: %s", wallet2_amount);
        check(wallet2_amount == start_amount2-amount-fee, "wallet 2 did not lose correct amount of money");

        auto wallet3_dartcheckread = wallet3.getRequestCheckWallet(wallet3_hirpc);
        auto wallet3_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet3_dartcheckread);

        // writefln("RECEIVED RESPONSE: %s", wallet3_received_doc.toPretty);
        auto wallet3_received = wallet3_hirpc.receive(wallet3_received_doc);
        check(wallet3.setResponseCheckRead(wallet3_received), "wallet3 not updated succesfully");
        
        auto wallet3_amount = wallet3.calcTotal(wallet3.account.bills);
        writefln("WALLET 3 amount: %s", wallet3_amount);
        check(wallet3_amount == start_amount3+amount, format("did not receive money correct amount of money should have %s had %s", start_amount3+amount, wallet3_amount));
        return result_ok;
    }

}

@safe @Scenario("Bill age",
        [])
class BillAge {
    Options opts1;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract;
    TagionCurrency amount;
    TagionCurrency fee;

    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    this(Options opts1, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;

        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
        
    }

    @Given("i pay a contract where the output bills timestamp is newer than epoch_time + constant.")
    Document constant() {

        import tagion.utils.StdTime;
        import std.datetime;
        import tagion.services.transcript : BUFFER_TIME_SECONDS;

        amount = 100.TGN;
        auto new_time = sdt_t((SysTime(cast(long) currentTime) + BUFFER_TIME_SECONDS.seconds + 100.seconds).stdTime);

        auto payment_request = wallet2.requestBill(amount, new_time);

        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating payment");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");

        return result_ok;
    }

    @When("i send the contract to the network.")
    Document network() {
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1.net);
        return result_ok;
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT))();

        auto wallet1_dartcheckread = wallet1.getRequestCheckWallet(wallet1_hirpc);
        auto wallet1_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet1_dartcheckread);

        writefln("RECEIVED RESPONSE: %s", wallet1_received_doc.toPretty);
        auto wallet1_received = wallet1_hirpc.receive(wallet1_received_doc);
        check(wallet1.setResponseCheckRead(wallet1_received), "wallet1 not updated succesfully");


        auto wallet1_total_amount = wallet1.account.total;
        writefln("WALLET 1 TOTAL amount: %s", wallet1_total_amount);
        check(wallet1_total_amount == start_amount1, format("wallet total amount not correct. expected: %s, had %s", start_amount1, wallet1_total_amount));

        auto wallet2_dartcheckread = wallet2.getRequestCheckWallet(wallet2_hirpc);
        auto wallet2_received_doc = sendDARTHiRPC(opts1.dart_interface.sock_addr, wallet2_dartcheckread);

        auto wallet2_received = wallet2_hirpc.receive(wallet2_received_doc);
        check(wallet2.setResponseCheckRead(wallet2_received), "wallet2 not updated succesfully");
        
        auto wallet2_amount = wallet2.calcTotal(wallet2.account.bills);
        writefln("WALLET 2 amount: %s", wallet2_amount);
        check(wallet2_amount == start_amount2, "should not receive new money");
        
        return result_ok;
    }

}

