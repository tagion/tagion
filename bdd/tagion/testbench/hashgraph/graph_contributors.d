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


    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
        CALLS = cast(uint) node_names.length * 1000;

        
    } 
    @Given("i have a hashgraph testnetwork with n number of nodes")
    Document nodes() {

      

        
        network = new TestNetwork(node_names);

        auto exclude_channel = Pubkey(network.channels[network.random.value(0, network.channels.length)]);

       
        network.excluded_nodes_history = [23: exclude_channel];
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);
        network.global_time = SysTime.fromUnixTime(1_614_355_286);
        return result_ok;
    }

    @When("all nodes have created at least one epoch")
    Document epoch() {

        try {
            uint i = 0;
            while(i < CALLS) {
            
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
            
        return result_ok;
    }

    @Then("the network should still reach consensus")
    Document consensus() {
        return Document();
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
