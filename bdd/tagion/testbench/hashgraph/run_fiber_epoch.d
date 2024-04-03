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
import std.conv : to;
import std.exception : ifThrown;
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

    uint MAX_CALLS = args[1].to!uint.ifThrown(5000);
    int[] weights = args[2].split(",").map!(n => n.to!int).array;
    writefln("%s", weights);
    uint number_of_nodes = cast(uint) weights.length;
    
    // uint number_of_nodes = args[2].to!uint.ifThrown(5);


    auto hashgraph_fiber_feature = automation!(run_fiber_epoch);
    hashgraph_fiber_feature.RunPassiveFastHashgraph(number_of_nodes, weights, MAX_CALLS, module_path);
    hashgraph_fiber_feature.run;

    return 0;
}

@safe @Scenario("Run passive fast hashgraph",
        [])
class RunPassiveFastHashgraph {
    string[] node_names;
    string module_path;
    TestNetworkT!NewTestRefinement network;
    uint MAX_CALLS;
    uint number_of_nodes = 5;
    int[] weights;

    this(uint number_of_nodes, int[] weights, uint MAX_CALLS, string module_path) {
        this.number_of_nodes = number_of_nodes;
        this.module_path = module_path;
        this.node_names = number_of_nodes.iota.map!(i => format("Node_%s", i)).array;
        this.MAX_CALLS = MAX_CALLS;
        this.weights = weights;

        network = new TestNetworkT!(NewTestRefinement)(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 100);
        network.random.seed(123456789);
        writeln(network.random);
        network.global_time = SysTime.fromUnixTime(1_614_355_286);
    }

    @Given("i have a running hashgraph")
    Document hashgraph() @trusted {
        uint i = 0;

        import std.datetime.stopwatch;
        import std.datetime;
        auto sw = StopWatch(AutoStart.yes);

        
        import std.random : MinstdRand0, dice;
        auto rnd = MinstdRand0(42);

        while (i < MAX_CALLS) {
            size_t channel_number;
            if (NewTestRefinement.epochs.length > 0) {
                channel_number = rnd.dice(weights);
            } else {
                channel_number = network.random.value(0, network.channels.length);
            }
            // writefln("channel_number: %s", channel_number);
            network.current = Pubkey(network.channels[channel_number]);
            auto current = network.networks[network.current];
            // writefln("current: %(%02x%)", network.current);
            Event.callbacks = new FileMonitorCallBacks(buildPath(module_path, format("%(%02x%)_graph.hibon", network.current)), number_of_nodes, cast(Pubkey[]) network.channels);
            (() @trusted { current.call; Event.callbacks.destroy; })();
            // network.printStates;
            i++;
        }
        sw.stop;
        writefln("test took: %s", sw.peek);
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
