module tagion.testbench.hashgraph.exclude_node;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.stdio;

enum feature = Feature(
            "Hashgraph exclude node",
            ["This test is meant to test if a node completely stops communicating."]);

alias FeatureContext = Tuple!(
        StaticExclusionOfANode, "StaticExclusionOfANode",
        FeatureGroup*, "result"
);

@safe @Scenario("static exclusion of a node",
        [])
class StaticExclusionOfANode {

    @Given("i have a hashgraph testnetwork with n number of nodes")
    Document nodes() {
        writeln("wowo");
        return Document();
    }

    @When("all nodes have created at least one epoch")
    Document epoch() {
        return Document();
    }

    @When("i mark one node statically as non-voting and disable communication for him")
    Document him() {
        return Document();
    }

    @Then("the network should still reach consensus")
    Document consensus() {
        return Document();
    }

    @Then("stop the network")
    Document network() {
        return Document();
    }

}
