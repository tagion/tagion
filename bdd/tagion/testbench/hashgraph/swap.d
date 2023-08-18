module tagion.testbench.hashgraph.swap;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.testbench.hashgraph.hashgraph_test_network;
import tagion.crypto.Types : Pubkey;
import tagion.basic.Types : FileExtension;
import std.path : buildPath, setExtension, extension;
import tagion.utils.Miscellaneous : cutHex;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;

import std.stdio;
import std.algorithm;
import std.format;
import std.typecons;
import std.datetime;
import tagion.utils.Miscellaneous : cutHex;

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

    string[] node_names;
    TestNetwork network;
    string module_path;
    uint MAX_CALLS;
    Pubkey offline_key;
    enum new_node = "NEW_NODE";

    this(string[] node_names, const uint calls, const string module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
        MAX_CALLS = cast(uint) node_names.length * calls;
    }

    @Given("i have a hashgraph testnetwork with n number of nodes.")
    Document nodes() {

        network = new TestNetwork(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);
        writeln(network.random);

        network.global_time = SysTime.fromUnixTime(1_614_355_286);
        offline_key = Pubkey(network.channels[1]);

        auto net = new StdSecureNet();
        net.generateKeyPair(format("very secret %s", new_node));
        TestRefinement.swap = TestRefinement.Swap(offline_key, net.pubkey, 10);
        return result_ok;
    }

    @Given("that all nodes knows a node should be swapped.")
    Document swapped() {
        return result_ok;
    }

    @When("a node has created a specific amount of epochs, it swaps in the new node.")
    Document node() {
        foreach (i; 0 .. MAX_CALLS) {
            const channel_number = network.random.value(0, network.channels.length);
            const channel = network.channels[channel_number];
            network.current = Pubkey(channel);
            auto current = network.networks[channel];

            if (TestRefinement.epoch_events.length == node_names.length && TestRefinement.epoch_events
                    .byValue
                    .map!((ep) => ep.length)
                    .all!((ep_length) => ep_length > 2)) {
                break;
            }
            (() @trusted { current.call; })();
        }

        TestNetwork.TestGossipNet.online_states[offline_key] = !TestNetwork.TestGossipNet.online_states[offline_key];
        // TestNetwork.TestGossipNet.online_states[offline_key] = false;

        foreach (i; 0 .. MAX_CALLS) {
            const channel_number = network.random.value(0, network.channels.length);
            const channel = network.channels[channel_number];
            network.current = Pubkey(channel);
            auto current = network.networks[channel];

            (() @trusted { current.call; })();
        }

        writefln("ADDING NEW NODE");
        network.addNode(node_names.length, new_node, Yes.joining);

        foreach (i; 0 .. MAX_CALLS) {
            const channel_number = network.random.value(0, network.channels.length);
            const channel = network.channels[channel_number];
            network.current = Pubkey(channel);
            auto current = network.networks[channel];

            (() @trusted { current.call; })();
        }

        return result_ok;
    }

    @Then("the new node should come in graph.")
    Document graph() {
        return result_ok;
    }

    @Then("compare the epochs created from the point of the swap.")
    Document swap() {
        return result_ok;
    }

    @Then("stop the network.")
    Document _network() {
        Pubkey[string] node_labels;
        foreach (channel, _net; network.networks) {
            node_labels[_net._hashgraph.name] = channel;
        }
        foreach (_net; network.networks) {
            const filename = buildPath(module_path, "ripple-" ~ _net._hashgraph.name
                    .setExtension(FileExtension.hibon));
            writeln(filename);
            _net
                ._hashgraph.fwrite(filename, node_labels);
        }
        return result_ok;
    }

}
