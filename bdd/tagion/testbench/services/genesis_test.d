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
import core.time;

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

    @Given("i have a network booted with a genesis block")
    Document block() {
        submask.subscribe(StdRefinement.epoch_created);
        writeln("waiting for epoch");
        auto received = receiveTimeout(30.seconds, (LogInfo _, const(Document) __) {});
        epoch_on_startup = received;
        check(epoch_on_startup, "No epoch on startup");

        //check that network booted
        // empty
        return result_ok;
    }

    @When("the network continues to run.")
    Document run() {
        check(epoch_on_startup, "No epoch on startup");
        return Document();
    }

    @Then("it should continue adding blocks to the _epochchain")
    Document epochchain() {
        check(epoch_on_startup, "No epoch on startup");
        return Document();
    }

    @Then("check the chains validity.")
    Document validity() {
        check(epoch_on_startup, "No epoch on startup");
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
