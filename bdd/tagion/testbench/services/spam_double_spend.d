module tagion.testbench.services.spam_double_spend;
// Default import list for bdd
import std.typecons : Tuple;
import tagion.actor;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DARTcrud;
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
import tagion.utils.pretend_safe_concurrency : receiveOnly, receiveTimeout;
import tagion.wallet.request;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.wave.mode0;

import core.thread;
import core.time;
import std.algorithm;
import std.format;
import std.range;
import std.stdio;

alias StdSecureWallet = SecureWallet!StdSecureNet;

enum feature = Feature(
            "Spam the network with the same contracts until we know it does not go through.",
            []);

alias FeatureContext = Tuple!(
        SpamOneNodeUntil10EpochsHaveOccurred, "SpamOneNodeUntil10EpochsHaveOccurred",
        SpamMultipleNodesUntil10EpochsHaveOccurred, "SpamMultipleNodesUntil10EpochsHaveOccurred",
        FeatureGroup*, "result"
);

@safe @Scenario("Spam one node until 10 epochs have occurred.",
        [])
class SpamOneNodeUntil10EpochsHaveOccurred {

    Options node1_opts;
    const(Options)[] opts;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    TagionCurrency amount;
    TagionCurrency fee;
    //
    SignedContract signed_contract;
    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    this(const(Options[]) opts, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.node1_opts = opts[0];
        this.opts = opts;
        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("i have a correctly signed contract.")
    Document contract() {
        amount = 100.TGN;
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating payment wallet");

        return result_ok;
    }

    @When("i continue to send the same contract with n delay to one node.")
    Document node() {
        import tagion.hashgraph.Refinement : FinishedEpoch;

        thisActor.task_name = "spam_contract_task";
        log.registerSubscriptionTask(thisActor.task_name);
        submask.subscribe("epoch_creator/epoch_created");

        auto epoch_before = receiveOnlyTimeout!(LogInfo, const(Document))(env.EPOCH_TIMEOUT!uint.seconds);
        check(epoch_before[1].isRecord!FinishedEpoch, "not correct subscription received");
        long epoch_number = FinishedEpoch(epoch_before[1]).epoch;
        long current_epoch_number;

        while (current_epoch_number < epoch_number + 10) {
            sendHiRPC(node1_opts.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1_hirpc);
            (() @trusted => Thread.sleep(100.msecs))();

            auto current_epoch = receiveOnlyTimeout!(LogInfo, const(Document))(env.EPOCH_TIMEOUT!uint.seconds);
            check(current_epoch[1].isRecord!FinishedEpoch, "not correct subscription received");
            current_epoch_number = FinishedEpoch(current_epoch[1]).epoch;
            writefln("epoch_number %s, CURRENT EPOCH %s", epoch_number, current_epoch_number);
        }

        (() @trusted => Thread.sleep(env.CONTRACT_TIMEOUT!uint.seconds))();
        return result_ok;
    }

    @Then("only the first contract should go through and the other ones should be rejected.")
    Document rejected() {
        auto wallet1_amount = getWalletUpdateAmount(wallet1, node1_opts.rpcserver.sock_addr, wallet1_hirpc);
        auto wallet2_amount = getWalletUpdateAmount(wallet2, node1_opts.rpcserver.sock_addr, wallet2_hirpc);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        writefln("WALLET 2 amount: %s", wallet2_amount);

        const expected_amount1 = start_amount1 - amount - fee;
        const expected_amount2 = start_amount2 + amount;
        check(wallet1_amount == expected_amount1, format(
                "wallet 1 did not lose correct amount of money should have %s had %s", expected_amount1, wallet1_amount));
        check(wallet2_amount == expected_amount2, format(
                "wallet 2 did not lose correct amount of money should have %s had %s", expected_amount2, wallet2_amount));

        return result_ok;
    }
}

import tagion.actor;

@safe
struct SpamWorker {
    void task(immutable(Options) opts, immutable(SecureNet) net, immutable(SignedContract) signed_contract) {
        HiRPC hirpc = HiRPC(net);

        runTimeout(100.msecs, {
            sendHiRPC(opts.inputvalidator.sock_addr, hirpc.submit(signed_contract), hirpc);
            log("sent contract");
        });
    }

}

@safe @Scenario("Spam multiple nodes until 10 epochs have occurred.",
        [])
class SpamMultipleNodesUntil10EpochsHaveOccurred {
    const(Options)[] opts;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    TagionCurrency amount;
    TagionCurrency fee;
    //
    SignedContract signed_contract;
    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    this(const(Options)[] opts, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts = opts;
        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("i have a correctly signed contract.")
    Document signedContract() {
        writefln("######## NEXT TEST ########");
        amount = 100.TGN;
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating payment wallet");

        return result_ok;
    }

    @When("i continue to send the same contract with n delay to multiple nodes.")
    Document multipleNodes() @trusted {
        import tagion.hashgraph.Refinement : FinishedEpoch, StdRefinement;

        ActorHandle[] handles;
        submask.subscribe(StdRefinement.epoch_created);

        foreach (i, opt; opts) {
            handles ~= spawn!SpamWorker(format("spam_worker%s", i),
                    cast(immutable) opt,
                    cast(immutable) wallet1.net,
                    cast(immutable) signed_contract
                );
        }

        writefln("waiting for alive");
        waitforChildren(Ctrl.ALIVE, env.WAIT_UNTIL_ALIVE!uint.seconds);

        auto epoch_before = receiveOnlyTimeout!(LogInfo, const(Document))(env.EPOCH_TIMEOUT!uint.seconds);
        check(epoch_before[1].isRecord!FinishedEpoch, "not correct subscription received");
        long epoch_number = FinishedEpoch(epoch_before[1]).epoch;
        long current_epoch_number;

        auto node1_opts = opts[1];
        while (current_epoch_number < epoch_number + 10) {
            sendHiRPC(node1_opts.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1_hirpc);
            (() @trusted => Thread.sleep(100.msecs))();

            auto current_epoch = receiveOnlyTimeout!(LogInfo, const(Document))(env.EPOCH_TIMEOUT!uint.seconds);
            check(current_epoch[1].isRecord!FinishedEpoch, "not correct subscription received");
            current_epoch_number = FinishedEpoch(current_epoch[1]).epoch;
            writefln("epoch_number %s, CURRENT EPOCH %s", epoch_number, current_epoch_number);
        }

        foreach(handle; handles) {
            handle.send(Sig.STOP);
        }

        submask.unsubscribe(StdRefinement.epoch_created);

        writefln("waiting for end");
        waitforChildren(Ctrl.END);

        (() @trusted => Thread.sleep(env.CONTRACT_TIMEOUT!uint.seconds))();
        return result_ok;
    }

    @Then("only the first contract should go through and the other ones should be rejected.")
    Document beRejected() {
        auto node1_opts = opts[1];

        const expected_amount1 = start_amount1 - amount - fee;
        const expected_amount2 = start_amount2 + amount;
        TagionCurrency wallet1_amount;
        TagionCurrency wallet2_amount;

        wallet1_amount = getWalletUpdateAmount(wallet1, node1_opts.rpcserver.sock_addr, wallet1_hirpc);
        wallet2_amount = getWalletUpdateAmount(wallet2, node1_opts.rpcserver.sock_addr, wallet2_hirpc);
        writefln("WALLET 1 amount: %s", wallet1_amount);
        writefln("WALLET 2 amount: %s", wallet2_amount);

        check(wallet1_amount == expected_amount1, format(
                "wallet 1 did not lose correct amount of money should have %s had %s", expected_amount1, wallet1_amount));
        check(wallet2_amount == expected_amount2, format(
                "wallet 2 did not lose correct amount of money should have %s had %s", expected_amount2, wallet2_amount));

        return result_ok;
    }
}
