module tagion.testbench.hashgraph.synchron_network;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import std.stdio;
import tagion.testbench.hashgraph.hashgraph_test_network;
import std.algorithm;
import std.datetime;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.HashGraph;
import std.array;
import core.sys.posix.sys.resource;
import std.path : buildPath;
import std.path : setExtension, extension;
import tagion.basic.Types : FileExtension;
import std.range;
import std.array;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hashgraph.HashGraphBasic;

enum feature = Feature(
            "Bootstrap of hashgraph",
            []);

alias FeatureContext = Tuple!(
        StartNetworkWithNAmountOfNodes, "StartNetworkWithNAmountOfNodes",
        FeatureGroup*, "result"
);

@safe @Scenario("Start network with n amount of nodes",
        [])
class StartNetworkWithNAmountOfNodes {
    string[] node_names;
    TestNetwork network;
    string module_path;

    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
    }

    bool coherent;

    bool allCoherent() {
    
        return network.networks
                .byValue
                .map!(n => n._hashgraph.owner_node.sticky_state)
                .all!(s => s == ExchangeState.COHERENT);
    }

    void printStates() {
        foreach(channel; network.channels) {
            writeln("----------------------");
            foreach (channel_key; network.channels) {
                const current_hashgraph = network.networks[channel_key]._hashgraph;
                writef("%16s %10s ingraph:%5s|", channel_key.cutHex, current_hashgraph.owner_node.sticky_state, current_hashgraph.areWeInGraph);
                foreach (receiver_key; network.channels) {
                    const node = current_hashgraph.nodes.get(receiver_key, null);                
                    const state = (node is null) ? ExchangeState.NONE : node.state;
                    writef("%15s %s", state, node is null ? "X" : " ");
                }
                writeln;
            }
        }
    
    }


    void verifyEpochs(TestNetwork.Epoch[][Pubkey] epoch_events) {
        //
        // auto test = epoch_events.byKeyValue.slide(2);
        // pragma(msg, typeof(test.front));
        // test.popFront;
        // pragma(msg, typeof(test.front));
        // pragma(msg, __traits(allMembers, typeof(test.front)));
        // pragma(msg, __traits(allMembers, typeof(test.front.front)));


        foreach(epoch_pair; epoch_events.byKeyValue.slide(2)) {


            auto a = epoch_pair.front;
            epoch_pair.popFront;
            auto b = epoch_pair.front;
            pragma(msg, typeof(a.key));
            const l = min(a.value.length, b.value.length);
            check(l != 0, "node not started");
            foreach(i; 0..l) {
                const e = equal(a.value[i].events.map!(e => e.event_package), b.value[i].events.map!(e => e.event_package));

                check(e, "sikker noget skidt");
            }

        }   

        // }
        // uint i = 0;
        // while(true) {
        //     Epoch[] epoch_events[0][i];
        
        //     foreach(channel; epoch_events) {
        //         merge ~= 
        //     }
        //     i++;
        // }    
    }
    
    @Given("i have a HashGraph TestNetwork with n number of nodes")
    Document nodes() {
        rlimit limit;
        (() @trusted { getrlimit(RLIMIT_STACK, &limit); })();
        writefln("RESOURCE LIMIT = %s", limit);

        network = new TestNetwork(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);

        network.global_time = SysTime.fromUnixTime(1_614_355_286);

        return result_ok;
    }

    @When("the network has started")
    Document started() {

        try {
            foreach (channel; network.channels) {
                auto current = network.networks[channel];
                (() @trusted { current.call; })();
            }
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        return result_ok;

    }

    @When("all nodes are sending ripples")
    Document ripples() {



        try {
            foreach (i; 0 .. 1000) {
                const channel_number = network.random.value(0, network.channels.length);
                const channel = network.channels[channel_number];
                auto current = network.networks[channel];
                (() @trusted { current.call; })();

                printStates();
                if (allCoherent) {
                    coherent = true;
                    break;
                }
            }
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        


        return result_ok;
    }

    @When("all nodes are coherent")
    Document _coherent() {
        check(coherent, "Nodes not coherent");
        return Document();
    }

    @Then("wait until the first epoch")
    Document epoch() {

        try {
            foreach (i; 0 .. 500) {
                const channel_number = network.random.value(0, network.channels.length);
                network.current = Pubkey(network.channels[channel_number]);
                auto current = network.networks[network.current];
                (() @trusted { current.call; })();

                // if (network.epoch_events.length == node_names.length) {
                //     // all nodes have created at least one epoch
                //     break;
                // }
                printStates();
            }
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        check(network.epoch_events.length == node_names.length, "All nodes should have created a epoch");
        

        foreach(i, compare_epoch; network.epoch_events.byKeyValue.front.value) {
            const compare_events = compare_epoch.events
                                                .map!(e => e.event_package)
                                                .array;
            writefln("compare_events: %s", compare_events);
            foreach(channel_epoch; network.epoch_events.byKeyValue) {
                const events = channel_epoch.value[i]
                                            .events
                                            .map!(e => e.event_package)
                                            .array;
                writefln("events: %s", events);
                writefln("channel %s time: %s", channel_epoch.key.cutHex, channel_epoch.value[i].epoch_time);

                const isSame = equal(compare_events, events);
                writefln("isSame: %s", isSame);
                // check(isSame, "event pkgs not the same");            
            
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
        return Document();
    }

}
