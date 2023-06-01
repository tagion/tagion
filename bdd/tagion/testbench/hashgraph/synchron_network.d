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

        const channels = network.channels;

         
        return result_ok;
    }

    @When("the network has started")
    Document started() {
        return Document();
    }

    @When("all nodes are sending ripples")
    Document ripples() {
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
