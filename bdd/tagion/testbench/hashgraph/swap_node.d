module tagion.testbench.hashgraph.swap_node;
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
import std.array;
import std.path : buildPath, setExtension, extension;
import tagion.basic.Types : FileExtension;
import tagion.utils.Miscellaneous : cutHex;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraphview.Compare;
import tagion.hashgraph.Event;


enum feature = Feature(
            "Hashgraph swap node",
            [
        "This test is meant to test when a node has completely stopped communicating. That we can set it to null and add a new node in its position"
]);

alias FeatureContext = Tuple!(
        OfflineNodeSwap, "OfflineNodeSwap",
        FeatureGroup*, "result"
);

@safe @Scenario("Offline node swap",
        [])
class OfflineNodeSwap {

    TestNetwork network;
    string[] node_names;
    string module_path;
    uint CALLS;

    Pubkey offline_node;
    Pubkey new_node;
    
    this(string[] node_names, TestNetwork network, string module_path) {
        this.network = network;
        this.node_names = node_names;
        this.module_path = module_path;
        CALLS = cast(uint) node_names.length * 1000;
        foreach (channel; network.channels) {
            TestNetwork.TestGossipNet.online_states[channel] = true;
        }
        writefln("ONLINE: %s", TestNetwork.TestGossipNet.online_states);
    }
    @Given("i have a hashgraph testnetwork with n number of nodes")
    Document ofNodes() {
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456432789);
        network.global_time = SysTime.fromUnixTime(1_614_355_286);
        return result_ok;
    }

    @When("all nodes have created at least one epoch")
    Document oneEpoch() {
        uint i = 0;
        while (i < CALLS) {

            const channel_number = network.random.value(0, network.channels.length);
            network.current = Pubkey(network.channels[channel_number]);
            auto current = network.networks[network.current];
            (() @trusted { current.call; })();
            // printStates(network);
            i++;
            if (TestRefinement.epoch_events.length == node_names.length) {
                break;
            }
        }

        check(TestRefinement.epoch_events.length == node_names.length,
                format("Max calls %d reached, not all nodes have created epochs only %d",
                CALLS, TestRefinement.epoch_events.length));

    
        return result_ok;
    }

    @When("i disable all communication for one node.")
    Document oneNode() {
        const channel_number = network.random.value(0, network.channels.length);
        offline_node = Pubkey(network.channels[channel_number]);
        TestNetwork.TestGossipNet.online_states[offline_node] = false;
        writefln("stopped communication for %s", offline_node.cutHex);
        return result_ok;
    }

    @When("the node is marked as offline")
    Document asOffline() {
        bool allExcluded;
        uint i = 0;
        while (i < CALLS) {
            const channel_number = network.random.value(0, network.channels.length);
            network.current = Pubkey(network.channels[channel_number]);
            auto current = network.networks[network.current];
            (() @trusted { current.call; })();
            i++;
            allExcluded = network.networks.byValue
                .filter!(n => n._hashgraph.owner_node.channel != offline_node)
                .all!(n => n._hashgraph.excluded_nodes_mask.count == 1);
            if (allExcluded) { break; }

        }
        check(allExcluded, format("not all nodes excluded %s", offline_node.cutHex));
        return result_ok;
    }

    @Then("the node should be deleted from the nodes.")
    Document theNodes() {

        network.networks.byKeyValue
            .filter!(n => n.key != offline_node)
            .each!(n => check(n.value._hashgraph.nodes[offline_node].offline, format("Node %s did not mark offline node", n.key)));

        
        // foreach(net; network.networks.byKeyValue) {
        //     if (net.key == offline_node) { continue; }
        //     check(net.value._hashgraph.nodes[offline_node].offline, format("Node %s did not mark offline node", net.key));
        // }
        return result_ok;
    }

    @Then("a new node should take its place.")
    Document itsPlace() {

        return result_ok;
    }

    @Then("the new node should come in graph.")
    Document inGraph() {
        return result_ok;
    }

    @Then("compare the epochs the node creates from the point of swap.")
    Document ofSwap() {
        return result_ok;
    }

    @Then("stop the network.")
    Document theNetwork() {
        // create ripple files.
        Pubkey[string] node_labels;
        foreach (channel, _net; network.networks) {
            node_labels[_net._hashgraph.name] = channel;
        }
        foreach (_net; network.networks) {
            const filename = buildPath(module_path, "ripple-" ~ _net._hashgraph.name.setExtension(FileExtension.hibon));
            writeln(filename);
            _net._hashgraph.fwrite(filename, node_labels);
        }
        return result_ok;
    }

}
