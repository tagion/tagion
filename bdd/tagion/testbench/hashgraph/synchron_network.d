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
            foreach (i; 0 .. 1000) {
                const channel_number = network.random.value(0, network.channels.length);
                const channel = network.channels[channel_number];
                auto current = network.networks[channel];
                (() @trusted { current.call; })();

           }
        }
        catch (Exception e) {
            check(false, e.msg);
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
