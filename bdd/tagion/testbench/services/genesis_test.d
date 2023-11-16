module tagion.testbench.services.genesis_test;
// Default import list for bdd
import std.typecons : Tuple;
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import std.stdio;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.hashgraph.Refinement;
import tagion.utils.pretend_safe_concurrency;
import tagion.testbench.actor.util;
import core.time;
import std.range;
import std.array;
import tagion.dart.Recorder;
import tagion.services.replicator : modify_log;
import tagion.actor;
import tagion.services.options;
import tagion.crypto.SecureInterfaceNet;
import std.format;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.script.common;
import tagion.crypto.SecureNet : StdHashNet;
import std.algorithm;
import core.thread;
import std.exception;
import tagion.crypto.Types;
import tagion.script.TagionCurrency;
import tagion.tools.wallet.WalletInterface;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.basic.Types : Buffer;
import tagion.utils.StdTime;
import tagion.communication.HiRPC;

enum EPOCH_TIMEOUT = 15;
alias StdSecureWallet = SecureWallet!StdSecureNet;

enum feature = Feature(
            "Boot system with genesis block.",
            []);

alias FeatureContext = Tuple!(
        NetworkRunningWithGenesisBlockAndEpochChain, "NetworkRunningWithGenesisBlockAndEpochChain",
        FeatureGroup*, "result"
);






@safe @Scenario("network running with genesis block and epoch chain.",
        [])
class NetworkRunningWithGenesisBlockAndEpochChain {
    bool epoch_on_startup;
    long start_epoch;
    RecordFactory record_factory;
    Options[] opts;
    ActorHandle[] handles;
    HashNet net = new StdHashNet;
    StdSecureWallet wallet1;
    TagionCurrency amount;
    TagionCurrency fee;

    const(GenesisEpoch) genesis_epoch;
    SignedContract signed_contract;

    
    struct History {
        TagionHead[] heads;
        Epoch[] epochs;
    }
    History[string] histories;

    this(Options[] opts, ref StdSecureWallet wallet1, const(GenesisEpoch) genesis_epoch) {
        this.opts = opts;
        record_factory = RecordFactory(net);
        this.wallet1 = wallet1;
        this.genesis_epoch = genesis_epoch;
    }

    @Given("i have a network booted with a genesis block")
    Document block() {

        amount = 500.TGN;
        auto bill_to_pay = TagionBill(amount, currentTime, Pubkey([0]), Buffer.init);
        check(wallet1.createPayment([bill_to_pay], signed_contract, fee).value, "Error creating payment");
        auto wallet1_hirpc = HiRPC(wallet1.net);
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);

        foreach(opt; opts) {
            histories[opt.task_names.replicator] = History.init;
        }

        writefln("signed_contract: %s", signed_contract.toPretty);



        submask.subscribe(modify_log);

        int max = 100;
        int start = 0;
        while(start < max) {
            if (start == 20) {
                sendSubmitHiRPC(opts[0].inputvalidator.sock_addr, hirpc_submit, wallet1.net);
            }
            auto modify_log_result = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
            log("received something");

            check(modify_log_result[1].isRecord!(RecordFactory.Recorder), "Did not receive recorder");
            // writefln("received recorder %s", modify_log_result[1].toPretty);

            auto recorder = record_factory.recorder(modify_log_result[1]);
            auto head = recorder[].filter!(a => a.filed.isRecord!TagionHead).array;
            check(head.length == 1, format("Should contain only one head per modify. had %s", head.length));


            const task_name = modify_log_result[0].task_name;
            
            histories[task_name].heads ~= TagionHead(head.front.filed); 

            auto epochs = recorder[]
                    .filter!(a => a.filed.isRecord!Epoch)
                    .map!(a => Epoch(a.filed))
                    .filter!(e => !e.previous.empty)
                    .array;

            histories[task_name].epochs ~= epochs;
            writefln("EPOCH NUMBERS %s", epochs.map!(e => format("%(%02x%)", e.previous)).array);


            start++;
        }
        // (() @trusted => writefln("%s", histories))();

        return result_ok;
    }

    @When("the network continues to run.")
    Document run() @trusted {
        // start by sorting the histories

        History[string] sorted_histories;

        foreach(hist; histories.byKeyValue) {
            auto sorted_epochs = hist.value.epochs.sort!((a,b) => a.epoch_number < b.epoch_number).array;
            auto sorted_heads = hist.value.heads.sort!((a,b) => a.current_epoch < b.current_epoch).array;
            check(sorted_epochs.length <= sorted_heads.length, format("there should be equal or more heads than the total amount of epochs, heads %s, epochs %s", sorted_heads.length, sorted_epochs.length));
            History sorted_hist;
            sorted_hist.epochs = sorted_epochs;
            sorted_hist.heads = sorted_heads;
            sorted_histories[hist.key] = sorted_hist;
        }

        // since we need to ref to the previous element we use a for loop over the epochs since we know that there must be fewer epochs than heads.

        Epoch[] ref_epochs = sorted_histories.byValue.front.epochs.array;

        // we first check that the epoch for the first is node created correctly. Then we compare the different epochs afterwards
        for (int i = 1; i < ref_epochs.length; i++) {
            auto ref_epoch = ref_epochs[i];
            auto prev_epoch = ref_epochs[i-1];

            writefln("comparing %s", i);
            check(ref_epoch.epoch_number == prev_epoch.epoch_number +1, "The epoch number was not correctly incremented");
            auto previous = net.calcHash(prev_epoch);
            check(previous == ref_epoch.previous, format("The fingerprint was not correct. should be %(%02x%) was %(%02x%)", previous, ref_epoch.previous));

            if (ref_epoch.globals != prev_epoch.globals) {
                writefln("NEW DIF EPOCH %s\n PREV EPOCH %s", ref_epoch.globals.toPretty, prev_epoch.globals.toPretty);

                
                // this was the epoch where our tx should have gone through
                check(ref_epoch.globals.total < prev_epoch.globals.total, format("the total was not decreased previous %s current %s", prev_epoch.globals.total, ref_epoch.globals.total));
                auto delta_bills = PayScript(signed_contract.contract.script).outputs.length - signed_contract.contract.inputs.length; 
                check(ref_epoch.globals.burnt_bills - 1 == prev_epoch.globals.burnt_bills, "the contract should have burned a bill");
                check(prev_epoch.globals.total_burned + fee.axios == ref_epoch.globals.total_burned, "the burned amount was not correct");
                check(ref_epoch.globals.number_of_bills - delta_bills == prev_epoch.globals.number_of_bills, "We should have updated the number of bills");
            }
            
            // check(ref_epoch.globals == prev_epoch.globals, "The globals should not have changed since no tx has gone through");


            foreach(hist; sorted_histories.byValue) {
                if (hist.epochs.length < i-1) {
                    continue;
                }
                check(hist.epochs[i] == ref_epoch, "The epoch was different across the nodes");
            }
        }
        return result_ok;
    }



    @Then("it should continue adding blocks to the _epochchain")
    Document epochchain() {
        return result_ok;
    }

    @Then("check the chains validity.")
    Document validity() {
        return result_ok;
    }

}

