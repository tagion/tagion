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
    
    this(string[] node_names) {
        this.node_names = node_names;
    }
    
    @Given("i have a HashGraph TestNetwork with n number of nodes")
    Document nodes() {
        network = new TestNetwork(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);

        network.global_time = SysTime.fromUnixTime(1_614_355_286);
        
        return result_ok;
    }

    @When("the network has started")
    Document started() {

        try {
            foreach(channel; network.channels) {
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
            foreach (i; 0 .. 550) {
                const channel_number = network.random.value(0, network.channels.length);
                const channel = network.channels[channel_number];
                auto current = network.networks[channel];
                writefln("calling channel %s", channel_number);
                (() @trusted { current.call; })();
            }
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        // Pubkey[bool] received_ripple;

        // try {
        //     while(received_ripple.length < node_names.length) {
        //         const channel_number = network.random.value(0, channels.length);
        //         const channel = network.channels[channel_number];
        //         auto current = network.networks[channel];
        //         (() @trusted { current.call; })();
        //     } 
        // }
        // catch(Exception e) {
        //     check(false, e.msg);
        // }
        

        
        // auto names = network.networks.byValue
        //     .map!((net) => net._hashgraph.name)
        //     .array.dup
        //     .sort
        //     .array;

        // HashGraph[string] hashgraphs;
        // foreach (net; network.networks) {
        //     hashgraphs[net._hashgraph.name] = net._hashgraph;
        // }

        // writefln("Save Alice");
        // Pubkey[string] node_labels;

        // foreach (channel, _net; network.networks) {
        //     node_labels[_net._hashgraph.name] = channel;
        // }
        // foreach (_net; network.networks) {
        //     const filename = fileId(_net._hashgraph.name);
        //     writeln(filename.fullpath);
        //     _net._hashgraph.fwrite(filename.fullpath, node_names);
        // }

        return Document();
    }

    @When("all nodes are coherent")
    Document coherent() {
        return Document();
    }

    @Then("wait until the first epoch")
    Document epoch() {
        return Document();
    }

    @Then("stop the network")
    Document _network() {
        return Document();
    }

}
