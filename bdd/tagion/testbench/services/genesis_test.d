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

enum EPOCH_TIMEOUT = 15;

enum feature = Feature(
            "Boot system with genesis block.",
            []);

alias FeatureContext = Tuple!(
        NetworkRunningWithGenesisBlockAndEpochChain, "NetworkRunningWithGenesisBlockAndEpochChain",
        CreateATransaction, "CreateATransaction",
        FeatureGroup*, "result"
);



@safe
struct EpochChainChecker {
    void task(immutable(Options) opts) {
        HashNet net = new StdHashNet;
        RecordFactory record_factory = RecordFactory(net);

        setState(Ctrl.ALIVE);
        log.registerSubscriptionTask(thisActor.task_name);
        submask.subscribe(modify_log);

        int max = 10;
        int start = 0;
        while(!thisActor.stop && start < max) {
            auto modify_log_result = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
            log("received something");
            if (modify_log_result[0].task_name != opts.task_names.replicator) {
                continue;
            }

            check(modify_log_result[1].isRecord!(RecordFactory.Recorder), "Did not receive recorder");

            log("received recorder %s", modify_log_result[1].toPretty);
            auto recorder = record_factory.recorder(modify_log_result[1]);
            auto head = recorder[].filter!(a => a.filed.isRecord!TagionHead).array;
            check(head.length == 1, format("Should contain only one head per modify. had %s", head.length));
            start++;
        }
        end();
    }
}








@safe @Scenario("network running with genesis block and epoch chain.",
        [])
class NetworkRunningWithGenesisBlockAndEpochChain {
    bool epoch_on_startup;
    long start_epoch;
    RecordFactory record_factory;
    Options[] opts;
    ActorHandle[] handles;

    this(Options[] opts) {
        this.opts = opts;
    }

    @Given("i have a network booted with a genesis block")
    Document block() {
        foreach(i, opt; opts) {
            const task_name = format("chain_checker_%s", i);
            handles ~= spawn!EpochChainChecker(task_name, cast(immutable) opt);
        }
        waitforChildren(Ctrl.ALIVE, 5.seconds);
        writeln("WAITING FOR CHILDRENT");
        (()@trusted => Thread.sleep(100.seconds))();


        
        // submask.subscribe(StdRefinement.epoch_created);
        // writeln("waiting for epoch");
        // auto received = receiveTimeout(30.seconds, (LogInfo _, const(Document) doc) 
        //     {
        //         start_epoch = FinishedEpoch(doc).epoch;
        //     });
        // epoch_on_startup = received;
        // check(epoch_on_startup, "No epoch on startup");

        return result_ok;
    }

    @When("the network continues to run.")
    Document run() {
        // check(epoch_on_startup, "No epoch on startup");

        // // run the network for 20 epochs
        // long current_epoch_number;
        // while(current_epoch_number < start_epoch + 20) {
        //     auto current_epoch = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT.seconds);
        //     current_epoch_number = FinishedEpoch(current_epoch[1]).epoch;
        // }
        // submask.unsubscribe(StdRefinement.epoch_created);
        return result_ok;
    }



    @Then("it should continue adding blocks to the _epochchain")
    Document epochchain() {



        
        // subscribe to the modify_log and see that the new head is always updated 
        // check for 10 epochs
        return result_ok;
    }

    @Then("check the chains validity.")
    Document validity() {
        return Document();
    }

}

@safe @Scenario("create a transaction",
        [])
class CreateATransaction {

    @Given("i have a payment request")
    Document request() {
        return Document();
    }

    @When("i pay the transaction")
    Document transaction() {
        return Document();
    }

    @Then("the networks tagion globals amount should be updated.")
    Document updated() {
        return Document();
    }

}
