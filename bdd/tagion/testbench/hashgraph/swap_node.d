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
        return Document();
    }

    @When("all nodes have created at least one epoch")
    Document oneEpoch() {
        return Document();
    }

    @When("i disable all communication for one node.")
    Document oneNode() {
        return Document();
    }

    @When("the node is marked as offline")
    Document asOffline() {
        return Document();
    }

    @Then("the node should be deleted from the nodes.")
    Document theNodes() {
        return Document();
    }

    @Then("a new node should take its place.")
    Document itsPlace() {
        return Document();
    }

    @Then("the new node should come in graph.")
    Document inGraph() {
        return Document();
    }

    @Then("compare the epochs the node creates from the point of swap.")
    Document ofSwap() {
        return Document();
    }

    @Then("stop the network.")
    Document theNetwork() {
        return Document();
    }

}
