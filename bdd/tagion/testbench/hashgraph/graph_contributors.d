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
import std.path : buildPath, setExtension, extension;
import tagion.basic.Types : FileExtension;
import std.stdio;
import tagion.hashgraph.HashGraph;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraphview.Compare;
import tagion.hashgraph.Event;
import std.functional : toDelegate;
import std.array;
import std.datetime;
import std.algorithm;
import std.format;
import tagion.hashgraph.Refinement;

import std.algorithm.comparison;

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
    TestNetwork network;


    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
        CALLS = cast(uint) node_names.length * 1000;

    }

    @Given("i have a hashgraph testnetwork with n number of nodes")
    Document nodes() {

      

        

        network = new TestNetwork(node_names);
        auto exclude_channel = Pubkey(network.channels[$-1]);
        auto second_exclude = Pubkey(network.channels[$-2]);
        
        TestRefinement.excluded_nodes_history = [21: exclude_channel, 22: second_exclude, 28: second_exclude, 32: exclude_channel];
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
                printStates(network);
                i++;
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

    @When("i mark one node as non-voting")
    Document nonvoting() {
        // done in history            
        return result_ok;
    }

    @Then("the network should still reach consensus")
    Document consensus() @trusted {

        // // compare ordering
        // auto names = network.networks.byValue
        //     .map!((net) => net._hashgraph.name)
        //     .array.dup
        //     .sort
        //     .array;

        // HashGraph[string] hashgraphs;
        // foreach (net; network.networks) {
        //     hashgraphs[net._hashgraph.name] = net._hashgraph;
        // }
        // foreach (i, name_h1; names[0 .. $ - 1]) {
        //     const h1 = hashgraphs[name_h1];
        //     foreach (name_h2; names[i + 1 .. $]) {
        //         const h2 = hashgraphs[name_h2];
        //         auto comp = Compare(h1, h2, toDelegate(&event_error));
        //         // writefln("%s %s round_offset=%d order_offset=%d",
        //         //     h1.name, h2.name, comp.round_offset, comp.order_offset);
        //         const result = comp.compare;
        //         check(result, format("HashGraph %s and %s is not the same", h1.name, h2.name));
        //     }
        // }
        // compare epochs
        // void compareMismatch(Buffer[] a, Buffer[] b, Event[] events) {

        //     const misses = mismatch(a, b);
        //     foreach(mis; misses[1]) {
        //         const pos = countUntil(b, mis);
        //     }
        // }
        
        
        foreach(i, compare_epoch; TestRefinement.epoch_events.byKeyValue.front.value) {
            auto compare_events = compare_epoch
                                            .events
                                            .array;
            writefln("%s", compare_events.map!(e => e.event_package.fingerprint.cutHex));
            foreach(channel_epoch; TestRefinement.epoch_events.byKeyValue) {
                writefln("epoch: %s", i);
                if (channel_epoch.value.length-1 < i) {
                    break;
                }
                auto events = channel_epoch.value[i]
                                            .events
                                            .array;

                writefln("%s", events.map!(e => e.event_package.fingerprint.cutHex));
                // events.each!writeln;
                writefln("channel %s time: %s", channel_epoch.key.cutHex, channel_epoch.value[i].epoch_time);

                if (compare_events.length != events.length) {
                    writefln("events not the same length. Was %d and %d", compare_events.length, events.length);
                }               
                check(compare_events.length == events.length, format("event_packages not the same length. Was %d and %d", compare_events.length, events.length));

                const compare_fingerprints = compare_events.map!(e => e.event_package.fingerprint).array;
                const event_fingerprints = events.map!(e => e.event_package.fingerprint).array;
                const isSame = equal(compare_fingerprints, event_fingerprints);
                writefln("isSame: %s", isSame);

                // const misses = mismatch(compare_events, events);
                // misses[1].each!writeln;
                check(isSame, "event_packages not the same");            

            
            }
        }         
        return result_ok;
    }

    @Then("stop the network")
    Document _network() {

    
    foreach(i, compare_epoch; TestRefinement.epoch_events.byKeyValue.front.value) {
        auto compare_events = compare_epoch
                                        .events
                                        .array;
        foreach(channel_epoch; TestRefinement.epoch_events.byKeyValue) {
            if (channel_epoch.value.length-1 < i) {
                break;
            }
            auto events = channel_epoch.value[i]
                                        .events
                                        .array;
            auto misses = mismatch!((a,b) => a.event_package.fingerprint == b.event_package.fingerprint)(compare_events, events);

            foreach(event_miss; misses.array.join) {
                writefln("event_miss %s", event_miss.event_package.fingerprint.cutHex);

                event_miss.error = true;
            }
        }
    } 
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
