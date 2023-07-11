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
import std.array;
import std.path : buildPath, setExtension, extension;
import tagion.basic.Types : FileExtension;
import tagion.utils.Miscellaneous : cutHex;


import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraphview.Compare;
import tagion.hashgraph.Event;
import std.functional : toDelegate;


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
        foreach(channel; network.channels) {
            TestNetwork.TestGossipNet.online_states[channel] = true;
        }
        writefln("ONLINE: %s", TestNetwork.TestGossipNet.online_states);
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
        //we are excluding one node. We continue until that epoch where we afterwards break all communication with him.
        try {
            uint i = 0;
            while (i < CALLS) {
                const channel_number = network.random.value(0, network.channels.length);
                network.current = Pubkey(network.channels[channel_number]);
                auto current = network.networks[network.current];
                (() @trusted { current.call; })();

                if (i == 10) {
                    TestNetwork.TestGossipNet.online_states[network.current] = false;
                    writefln("excluding: %s", network.current.cutHex);
                    writefln("after exclude %s", TestNetwork.TestGossipNet.online_states);
                }

                i++;
            }
        } catch (Exception e) {
            check(false, e.msg);
        }
        
        return result_ok;
    }

    @Then("the network should still reach consensus")
    Document consensus() @trusted {
       
        // compare graph
        auto names = network.networks.byValue
            .map!((net) => net._hashgraph.name)
            .array.dup
            .sort
            .array;

        HashGraph[string] hashgraphs;
        foreach (net; network.networks) {
            hashgraphs[net._hashgraph.name] = net._hashgraph;
        }
        foreach (i, name_h1; names[0 .. $ - 1]) {
            const h1 = hashgraphs[name_h1];
            foreach (name_h2; names[i + 1 .. $]) {
                const h2 = hashgraphs[name_h2];
                auto comp = Compare(h1, h2, toDelegate(&event_error));
                // writefln("%s %s round_offset=%d order_offset=%d",
                //     h1.name, h2.name, comp.round_offset, comp.order_offset);
                const result = comp.compare;
                check(result, format("HashGraph %s and %s is not the same", h1.name, h2.name));
            }
        }

        // compare epochs
        foreach(i, compare_epoch; TestRefinement.epoch_events.byKeyValue.front.value) {
            auto compare_events = compare_epoch
                                            .events
                                            .map!(e => e.event_package.fingerprint)
                                            .array;
            writefln("%s", compare_events.map!(f => f.cutHex));
            foreach(channel_epoch; TestRefinement.epoch_events.byKeyValue) {
                writefln("epoch: %s", i);
                if (channel_epoch.value.length-1 < i) {
                    break;
                }
                auto events = channel_epoch.value[i]
                                            .events
                                            .map!(e => e.event_package.fingerprint)
                                            .array;

                writefln("%s", events.map!(f => f.cutHex));
                // events.each!writeln;
                writefln("channel %s time: %s", channel_epoch.key.cutHex, channel_epoch.value[i].epoch_time);
                               
                check(compare_events.length == events.length, "event_packages not the same length");

                const isSame = equal(compare_events, events);
                writefln("isSame: %s", isSame);
                check(isSame, "event_packages not the same");            
            
            }
        }        
        return result_ok;
    }

    @Then("stop the network")
    Document _network() {
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
