module tagion.testbench.services.double_spend;
// Default import list for bdd
import core.thread;
import core.time;
import std.algorithm;
import std.concurrency : thisTid;
import std.format;
import std.range;
import std.stdio;
import std.typecons : Tuple;
import tagion.actor;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DARTcrud;
import tagion.hashgraph.Refinement;
import tagion.hibon.Document;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.script.Currency : totalAmount;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.execute;
import tagion.services.options;
import tagion.testbench.actor.util;
import tagion.testbench.services.helper_functions;
import tagion.testbench.tools.Environment;
import tagion.tools.wallet.WalletInterface;
import tagion.utils.pretend_safe_concurrency : receiveOnly, receiveTimeout, register;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.wallet.request;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum CONTRACT_TIMEOUT = 40;
enum EPOCH_TIMEOUT = 15;

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
        const fees = ContractExecution.billFees(collected_bills.map!(b=> b.toDoc), pay_script.outputs.map!(b => b.toDoc), 20);

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
        writefln("---SUBMIT ADDRESS--- %s", opts.rpcserver.sock_addr); 
        sendHiRPC(opts.rpcserver.sock_addr, hirpc_submit, wallet1_hirpc);

        return result_ok;
    }
    @Then("the contract should be rejected.")
    Document dart() {
        auto result = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
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
        const fees = ContractExecution.billFees(collected_bills.map!(b=> b.toDoc), pay_script.outputs.map!(b=> b.toDoc),100);

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
        writefln("---SUBMIT ADDRESS--- %s", opts.rpcserver.sock_addr); 
        sendHiRPC(opts.rpcserver.sock_addr, hirpc_submit, wallet1_hirpc);

        return result_ok;
    }
    @Then("the contract should be rejected.")
    Document dart() {
        auto result = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
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
        sendHiRPC(opts1.rpcserver.sock_addr, wallet1_hirpc.submit(signed_contract1), wallet1_hirpc);
        sendHiRPC(opts2.rpcserver.sock_addr, wallet2_hirpc.submit(signed_contract2), wallet2_hirpc);
        return result_ok;
    }

    @Then("both contracts should go through.")
    Document through() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();


        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.rpcserver.sock_addr, wallet1_hirpc);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        check(wallet1_amount == start_amount1 - fee, "did not receive tx");
        
        auto wallet2_amount = getWalletUpdateAmount(wallet1, opts1.rpcserver.sock_addr, wallet2_hirpc);
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
        sendHiRPC(opts1.rpcserver.sock_addr, hirpc_submit,wallet1_hirpc);
        sendHiRPC(opts2.rpcserver.sock_addr, hirpc_submit,wallet1_hirpc);

        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();
        return result_ok;
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.rpcserver.sock_addr, wallet1_hirpc);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        const wallet1_expected = start_amount1-amount-fee;
        check(wallet1_amount == wallet1_expected, format("wallet 1 did not lose correct amount of money, should have %s, had %s", wallet1_expected, wallet1_amount));

        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.rpcserver.sock_addr, wallet2_hirpc);
        writefln("WALLET 2 amount: %s", wallet2_amount);
        check(wallet2_amount == start_amount2+amount, "did not receive money");
        return result_ok;


        
        const wallet2_expected = start_amount2+amount;
        check(wallet2_amount == wallet2_expected, format("wallet 2 did not lose correct amount of money, should have %s, had %s", wallet2_expected, wallet2_amount));
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

        long epoch_number;
        uint max_tries = 20;
        uint counter;
        do {
            auto epoch_before = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
            writefln("epoch_before %s looking for %s", epoch_before[1], opts1.task_names.epoch_creator);
            check(epoch_before[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (epoch_before[0].task_name == opts1.task_names.epoch_creator) {
                writefln("################### CAME IN ################");
                epoch_number = FinishedEpoch(epoch_before[1]).epoch;
            }
            counter++;
        } while(counter < max_tries && epoch_number is long.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        writefln("EPOCH NUMBER %s", epoch_number);

        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        sendHiRPC(opts1.rpcserver.sock_addr, hirpc_submit,wallet1_hirpc);

        long new_epoch_number;
        counter = 0;
        do {
            auto new_epoch = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
            writefln("new_epoch %s %s", new_epoch[0].topic_name, opts1.task_names.epoch_creator);
            check(new_epoch[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (new_epoch[0].task_name == opts1.task_names.epoch_creator) {
                writefln("UPDATING NEW EPOCH_NUMBER");
                new_epoch_number = FinishedEpoch(new_epoch[1]).epoch;
            }
            counter++;
        } while(counter < max_tries && new_epoch_number is long.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        submask.unsubscribe(StdRefinement.epoch_created);
        writefln("EPOCH NUMBER updated %s", new_epoch_number);
        check(epoch_number < new_epoch_number, "epoch number not updated");
        sendHiRPC(opts1.rpcserver.sock_addr, hirpc_submit, wallet1_hirpc);
        
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();
        return result_ok;
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.rpcserver.sock_addr, wallet1_hirpc);
        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.rpcserver.sock_addr, wallet2_hirpc);
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

        long epoch_number;
        do {
            auto epoch_before = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
            writefln("epoch_before %s looking for %s", epoch_before[1], opts1.task_names.epoch_creator);
            check(epoch_before[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (epoch_before[0].task_name == opts1.task_names.epoch_creator) {
                epoch_number = FinishedEpoch(epoch_before[1]).epoch;
            }
            counter++;
        } while(counter < max_tries && epoch_number is long.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        writeln("EPOCH NUMBER %s", epoch_number);

        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        sendHiRPC(opts1.rpcserver.sock_addr, hirpc_submit, wallet1_hirpc);

        long new_epoch_number;
        counter = 0;
        do {
            auto new_epoch = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
            writefln("new_epoch %s %s", new_epoch[1], opts1.task_names.epoch_creator);
            check(new_epoch[1].isRecord!FinishedEpoch, "not correct subscription received");
            if (new_epoch[0].task_name == opts2.task_names.epoch_creator) {
                writefln("UPDATING NEW EPOCH_NUMBER");
                long _new_epoch_number = FinishedEpoch(new_epoch[1]).epoch;
                if (_new_epoch_number > epoch_number) {
                    new_epoch_number = _new_epoch_number;
                }
            }
            counter++;
        } while(counter < max_tries && new_epoch_number is long.init);
        check(counter < max_tries, "did not receive epoch in max tries");

        writeln("EPOCH NUMBER updated %s", new_epoch_number);
        sendHiRPC(opts2.rpcserver.sock_addr, hirpc_submit, wallet1_hirpc);
        
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();
        return result_ok;
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.rpcserver.sock_addr, wallet1_hirpc);
        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.rpcserver.sock_addr, wallet2_hirpc);
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
        sendHiRPC(opts1.rpcserver.sock_addr, hirpc_submit1, wallet1_hirpc);
        sendHiRPC(opts2.rpcserver.sock_addr, hirpc_submit2, wallet2_hirpc);


        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();
        return result_ok;
    }

    @Then("only one output should be produced.")
    Document produced() {
        
        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.rpcserver.sock_addr, wallet1_hirpc);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        const expected = start_amount1-amount-fee;
        check(wallet1_amount == expected, format("wallet 1 did not lose correct amount of money should have %s had %s", expected, wallet1_amount));

        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts2.rpcserver.sock_addr, wallet2_hirpc);
        writefln("WALLET 2 amount: %s", wallet2_amount);
        check(wallet2_amount == start_amount2-amount-fee, "wallet 2 did not lose correct amount of money");

        auto wallet3_amount = getWalletUpdateAmount(wallet3, opts1.rpcserver.sock_addr, wallet3_hirpc);
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

        import std.datetime;
        version(NEW_TRANSCRIPT) {
            import tagion.services.trans;
        } else {
            import tagion.services.transcript : BUFFER_TIME_SECONDS;
        }
        import tagion.utils.StdTime;

        amount = 100.TGN;
        auto new_time = sdt_t((SysTime(cast(long) currentTime) + BUFFER_TIME_SECONDS.seconds + 100.seconds).stdTime);

        auto payment_request = wallet2.requestBill(amount, new_time);

        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating payment");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");

        return result_ok;
    }

    @When("i send the contract to the network.")
    Document network() {
        sendHiRPC(opts1.rpcserver.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1_hirpc);
        return result_ok;
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();

        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.rpcserver.sock_addr, wallet1_hirpc);
        auto wallet1_total_amount = wallet1.account.total;
        writefln("WALLET 1 TOTAL amount: %s", wallet1_total_amount);
        check(wallet1_total_amount == start_amount1, format("wallet total amount not correct. expected: %s, had %s", start_amount1, wallet1_total_amount));

        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.rpcserver.sock_addr, wallet2_hirpc);
        writefln("WALLET 2 amount: %s", wallet2_amount);
        check(wallet2_amount == start_amount2, "should not receive new money");
        
        return result_ok;
    }

}
