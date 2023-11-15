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

enum EPOCH_TIMEOUT = 15;

enum feature = Feature(
            "Boot system with genesis block.",
            []);

alias FeatureContext = Tuple!(
        NetworkRunningWithGenesisBlockAndEpochChain, "NetworkRunningWithGenesisBlockAndEpochChain",
        CreateATransaction, "CreateATransaction",
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
    struct History {
        TagionHead[] heads;
        Epoch[] epochs;
    }
    History[string] histories;

    this(Options[] opts) {
        this.opts = opts;
        record_factory = RecordFactory(net);
    }

    @Given("i have a network booted with a genesis block")
    Document block() {

        foreach(opt; opts) {
            histories[opt.task_names.replicator] = History.init;
        }


        submask.subscribe(modify_log);

        int max = 100;
        int start = 0;
        while(start < max) {
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
                    .filter!(e => e.previous !is Fingerprint.init)
                    .array;

            histories[task_name].epochs ~= epochs;
            writefln("EPOCH NUMBERS %s", epochs.map!(e => format("%(%02x%)", e.previous)).array);


            start++;
        }
        (() @trusted => writefln("%s", histories))();

        return result_ok;
    }

    @When("the network continues to run.")
    Document run() {
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

        for (int i = 1; i < ref_epochs.length; i++) {
            check(ref_epochs[i].epoch_number == ref_epochs[i-1].epoch_number +1, "The epoch number was not correctly incremented");
        }
        



        
        // get all the epochs for the first node
        // Epoch[] __test = histories.byValue.front.epochs.array;

        // for (i = 0; i < __test.length; i++) {
        //     if (i > 2) {
        //         // compare to the previous epoch
        //         check(__test[i].previous == net.calcHash(__test[i-1]), "The ref to the previous epoch was not correct");
        //         check(__test[i].epoch_number == __test[i-1].epoch_number +1, "The epoch number was not correctly incremented");
        //     }

        //     foreach(history; histories.byKeyValue) {


        //     }


        // }


        // for (i =0; i < __test.length; i++) {
        //     if (i > 2) [
        //         check(__test[i].epochs[i].previous == net.calcHash(__test

        //     }



        // }





        // // go through the first history in the array epochs.
        // foreach(i, ref_history; histories.byValue.front.epochs) {
        //     // compare the index to the ones with all the others.
        //     if (i > 2) {
        //         check(__test.epochs[i].previous == net.calcHash(ref_history.epochs[i-1]), "The fingerprint to the previous epoch does not match");
        //         check(__test.epochs[i].epoch_number == ref_history.epochs[i-1].epoch_number + 1, "The epoch was not incremented by 1");
        //     }
        //     foreach(history; histories.byKeyValue) {
        //         if (history.value.heads.length < i) {
        //             break;
        //         }

        //         check(history.value.heads[i] == ref_history.heads[i], "heads are not the same");

        //         writefln("comparing %s to task_name %s", i, history.key);


        //     }


        // }

        
        // x
        // foreach(i, ref_history; histories.byValue.front) {
        //     foreach(history; histories.byKeyValue) {
        //         if(history.value.heads.length-1 < i) {
        //             writeln("BREAKING");
        //             break;
        //         }
        //         writeln("COMPARING");
        //         auto head = history.value.heads[i];
        //         check(head == ref_history.value.heads[i], "heads not the same");
        //     }



        // }




        
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

@safe @Scenario("create a transaction",
        [])
class CreateATransaction {

    @Given("i have a payment request")
    Document request() {
        return result_ok;
    }

    @When("i pay the transaction")
    Document transaction() {
        return result_ok;
    }

    @Then("the networks tagion globals amount should be updated.")
    Document updated() {
        return result_ok;
    }

}
