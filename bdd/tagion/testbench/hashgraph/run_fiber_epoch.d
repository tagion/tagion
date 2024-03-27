module tagion.testbench.hashgraph.run_fiber_epoch;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import std.file : mkdirRecurse, rmdirRecurse, exists;
import std.path : buildPath;
import std.stdio;
import tagion.testbench.hashgraph;
import tagion.testbench.hashgraph.hashgraph_test_network;
import std.range;
import std.algorithm;
import tagion.crypto.Types : Pubkey;
import std.datetime.systime : SysTime;
import tagion.hashgraph.Event;
import std.format;
import tagion.monitor.Monitor;

enum feature = Feature(
            "Check hashgraph stability when runninng many epochs",
            []);

alias FeatureContext = Tuple!(
        RunPassiveFastHashgraph, "RunPassiveFastHashgraph",
        FeatureGroup*, "result"
);


mixin Main!(_main);
int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);

    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    writeln("WE ARE RUNNING SOMETHING");

    auto hashgraph_fiber_feature = automation!(run_fiber_epoch);
    hashgraph_fiber_feature.RunPassiveFastHashgraph(5, module_path);
    hashgraph_fiber_feature.run;

    return 0;
}

@safe @Scenario("Run passive fast hashgraph",
        [])
class RunPassiveFastHashgraph {
    string[] node_names;
    string module_path;
    TestNetwork network;
    enum MAX_CALLS = 1000;
    uint number_of_nodes = 5;

    this(uint number_of_nodes, string module_path) {
        this.number_of_nodes = number_of_nodes;
        this.module_path = module_path;
        this.node_names = number_of_nodes.iota.map!(i => format("Node_%s", i)).array;

        network = new TestNetwork(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 10);
        network.random.seed(123456789);
        writeln(network.random);
        network.global_time = SysTime.fromUnixTime(1_614_355_286);
    }

    @Given("i have a running hashgraph")
    Document hashgraph() @trusted {
        uint i = 0;
        while (i < MAX_CALLS) {
            writeln(i);
            const channel_number = network.random.value(0, network.channels.length);
            network.current = Pubkey(network.channels[channel_number]);
            auto current = network.networks[network.current];
            Event.callbacks = new FileMonitorCallBacks(buildPath(module_path, format("%(%02x%)_graph.hibon", network.current)), number_of_nodes, cast(Pubkey[]) network.channels);
            (() @trusted { current.call; })();
            i++;
        }
        return result_ok;
    }

    @When("the nodes creates epochs")
    Document epochs() {
        return result_ok;
    }

    @Then("the epochs should be the same")
    Document same() {
        return result_ok;
    }

}
