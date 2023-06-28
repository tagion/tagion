module tagion.testbench.hashgraph.graph_contributors;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.hashgraph.hashgraph_test_network;
import tagion.crypto.Types : Pubkey;

import std.datetime;
import std.algorithm;
import std.format;
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
    uint MAX_CALLS; 

    TestNetwork network;

    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
        MAX_CALLS = cast(uint) node_names.length * 1000;
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

        try {
            uint i = 0;
            while(i < MAX_CALLS) {
            
                const channel_number = network.random.value(0, network.channels.length);
                network.current = Pubkey(network.channels[channel_number]);
                auto current = network.networks[network.current];
                (() @trusted { current.call; })();

                if (network.epoch_events.length == node_names.length) {
                    // all nodes have created at least one epoch
                    break;
                }
                i++;
            }
            check(network.epoch_events.length == node_names.length, 
                format("Max calls %d reached, not all nodes have created epochs only %d", 
                MAX_CALLS, network.epoch_events.length));

        }
        catch (Exception e) {
            check(false, e.msg);
        }
        return result_ok;
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
