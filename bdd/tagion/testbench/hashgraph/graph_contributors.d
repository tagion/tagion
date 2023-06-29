module tagion.testbench.hashgraph.graph_contributors;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.testbench.hashgraph.hashgraph_test_network;
import tagion.crypto.Types : Pubkey;
import tagion.basic.basic : isinit;
import tagion.utils.BitMask;

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
    uint CALLS;
    // enum NON_VOTING = "Nonvoting";
    TestNetwork network;

    enum excluded_nodes_history = [23: BitMask([0])];

    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
        CALLS = cast(uint) node_names.length * 1000;

    }

    @Given("i have a hashgraph testnetwork with n number of nodes")
    Document nodes() {

        network = new TestNetwork(node_names);
        network.excluded_nodes_history = excluded_nodes_history;
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);
        network.global_time = SysTime.fromUnixTime(1_614_355_286);
        return result_ok;
    }

    @When("all nodes have created at least one epoch")
    Document epoch() {

        try {
            uint i = 0;
            while (i < CALLS) {

                const channel_number = network.random.value(0, network.channels.length);
                network.current = Pubkey(network.channels[channel_number]);
                auto current = network.networks[network.current];
                (() @trusted { current.call; })();

                i++;
            }
            check(network.epoch_events.length == node_names.length,
                    format("Max calls %d reached, not all nodes have created epochs only %d",
                    CALLS, network.epoch_events.length));

        }
        catch (Exception e) {
            check(false, e.msg);
        }
        return result_ok;
    }

    @When("i mark one node as non-voting")
    Document nonvoting() {

        // foreach(net; network.networks) {
        //     if (net._hashgraph.name == NON_VOTING) {
        //         non_voting = net;
        //         break;
        //     }
        // }
        // check(!non_voting.isinit, format("Name: %s not found in names", NON_VOTING));
        return result_ok;
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
