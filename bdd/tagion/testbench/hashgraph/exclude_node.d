module tagion.testbench.hashgraph.exclude_node;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.testbench.hashgraph.hashgraph_test_network;
import std.datetime;
import std.stdio;
import std.algorithm;
import std.format;
import tagion.crypto.Types;

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

    TestNetwork network;
    string[] node_names;
    string module_path;
    uint CALLS;

    this(string[] node_names, TestNetwork network, string module_path) {
        this.network = network;
        this.node_names = node_names;
        this.module_path = module_path;
        CALLS = cast(uint) node_names.length * 1000;
    }



    @Given("i have a hashgraph testnetwork with n number of nodes")
    Document nodes() {
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456432789);
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
                // printStates(network);
                i++;
                if (TestRefinement.epoch_events.length == node_names.length) { break; }
            }

            check(TestRefinement.epoch_events.length == node_names.length,
                    format("Max calls %d reached, not all nodes have created epochs only %d",
                    CALLS, TestRefinement.epoch_events.length));

        }
        catch (Exception e) {
            check(false, e.msg);
        }
        return result_ok;
    }

    @When("i mark one node statically as non-voting and disable communication for him")
    Document him() {
        // we are excluding one node. We continue until that epoch where we afterwards break all communication with him.

        // try {
        //     uint = 0;
        //     while (i < CALLS) {
        //         // get the current states of the nodes.
        //         const round_number = cast(int) i;
        //         auto histories = TestRefinement.excluded_nodes_history
        //                             .filter!(h => h.round < round_number-1)
        //                             .array
        //                             .sort!((a,b) => a.round < b.round);
        //         bool[Pubkey] current_states;
        //         foreach(hist; histories) {
        //             current_states[hist.pubkey] = hist.state;
        //         }
        //         // if (current_states !is null) {
        //         //     const callable = current_states
        //         //                         .byKeyValue
        //         //                         .filter!(h => !h.value)
        //         //                         .map!(h => h.key)
        //         //                         .array;
        //         // }
        //         // Pubkey current;
        //         // if (current_states !is null) {
                    
        //         // }

                

                
        //     }
        // }
        
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
