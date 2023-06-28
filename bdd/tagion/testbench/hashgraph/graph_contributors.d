module tagion.testbench.hashgraph.graph_contributors;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.hashgraph.hashgraph_test_network;

import std.datetime;
import std.algorithm;

enum feature = Feature(
            "Hashgraph contributors",
            [
        "This test is meant to test the ability for a node to get marked as non-voting which should result in the rest of the network continuing to run."
]);

alias FeatureContext = Tuple!(
        ANonvotingNode, "ANonvotingNode",
        FeatureGroup*, "result"
);

@safe @Scenario("a non-voting node",
        [])
class ANonvotingNode {
    string[] node_names;
    string module_path;

    TestNetwork network;

    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
    } 
    @Given("i have a hashgraph testnetwork with n number of nodes")
    Document nodes() {
        network = new TestNetwork(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);
        network.global_time = SysTime.fromUnixTime(1_614_355_286);
        return result_ok;
    }

    @When("all nodes have created at least one epoch")
    Document epoch() {
        return Document();
    }

    @When("i mark one node as non-voting")
    Document nonvoting() {
        return Document();
    }

    @Then("the network should still reach consensus")
    Document consensus() {
        return Document();
    }

    @Then("stop the network")
    Document _network() {
        return Document();
    }

}
