module tagion.testbench.services.genesis_test;
// Default import list for bdd
import std.typecons : Tuple;
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;

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

    @Given("i have a network booted with a genesis block")
    Document block() {
        return Document();
    }

    @When("the network continues to run.")
    Document run() {
        return Document();
    }

    @Then("it should continue adding blocks to the _epochchain")
    Document epochchain() {
        return Document();
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
