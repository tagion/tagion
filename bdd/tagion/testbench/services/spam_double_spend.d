module tagion.testbench.services.spam_double_spend;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Spam the network with the same contracts until we know it does not go through.",
            []);

alias FeatureContext = Tuple!(
        SpamOneNodeUntil10EpochsHaveOccured, "SpamOneNodeUntil10EpochsHaveOccured",
        SpamMultipleNodesUntil10EpochsHaveOccured, "SpamMultipleNodesUntil10EpochsHaveOccured",
        FeatureGroup*, "result"
);

@safe @Scenario("Spam one node until 10 epochs have occured.",
        [])
class SpamOneNodeUntil10EpochsHaveOccured {

    @Given("i have a correctly signed contract.")
    Document contract() {
        return Document();
    }

    @When("i continue to send the same contract with n delay to one node.")
    Document node() {
        return Document();
    }

    @Then("only the first contract should go through and the other ones should be rejected.")
    Document rejected() {
        return Document();
    }

    @Then("check that the bullseye is the same across all nodes.")
    Document nodes() {
        return Document();
    }

}

@safe @Scenario("Spam multiple nodes until 10 epochs have occured.",
        [])
class SpamMultipleNodesUntil10EpochsHaveOccured {

    @Given("i have a correctly signed contract.")
    Document signedContract() {
        return Document();
    }

    @When("i continue to send the same contract with n delay to multiple nodes.")
    Document multipleNodes() {
        return Document();
    }

    @Then("only the first contract should go through and the other ones should be rejected.")
    Document beRejected() {
        return Document();
    }

    @Then("check that the bullseye is the same across all nodes.")
    Document allNodes() {
        return Document();
    }

}
