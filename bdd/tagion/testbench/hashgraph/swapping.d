module tagion.testbench.hashgraph.swapping;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Hashgraph Swapping",
            ["This test is meant to test that a node can be swapped out at a specific epoch"]);

alias FeatureContext = Tuple!(
        NodeSwap, "NodeSwap",
        FeatureGroup*, "result"
);

@safe @Scenario("node swap",
        [])
class NodeSwap {

    @Given("i have a hashgraph testnetwork with n number of nodes.")
    Document nodes() {
        return Document();
    }

    @Given("that all nodes knows when a node should be swapped.")
    Document swapped() {
        return Document();
    }

    @When("a node has created a specific amount of epochs, it swaps in the new node.")
    Document node() {
        return Document();
    }

    @Then("the new node should come in graph.")
    Document graph() {
        return Document();
    }

    @Then("compare the epochs created from the point of the swap.")
    Document swap() {
        return Document();
    }

    @Then("stop the network.")
    Document network() {
        return Document();
    }

}
