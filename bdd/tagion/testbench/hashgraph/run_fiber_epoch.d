module tagion.testbench.hashgraph.run_fiber_epoch;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.basic.basic;
import tagion.basic.Types;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import std.file : mkdirRecurse, rmdirRecurse, exists;
import std.path : buildPath, setExtension;
import std.stdio;
import std.algorithm;
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
import tagion.tools.Basic;
import tagion.tools.revision;
import std.getopt;
import tagion.hibon.HiBONFile : fwrite;

enum feature = Feature(
            "Check hashgraph stability when runninng many epochs",
            []);

alias FeatureContext = Tuple!(
        RunPassiveFastHashgraph, "RunPassiveFastHashgraph",
        FeatureGroup*, "result"
);

mixin Main!(_main);
int _main(string[] args) {
    HashGraphOptions opts;
    immutable program = args[0];
    bool version_switch;
    opts.path = env.bdd_log.buildPath(__MODULE__);
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "N", "Number of nodes in the test", &opts.number_of_nodes,
                "R|rounds", "Number of rounds", &opts.max_epochs,
                "seed", "Random seed value", &opts.seed,
                "P|path", "File path for the generated files", &opts.path,
                "d", "Disable graph files", &opts.disable_graphfile,
                "k", "Continues on error with stoppig", &opts.continue_on_error,
        );
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }
        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                    "Documentation: https://docs.tagion.org/",
                    "",
                    "",
                    "Usage:",
                    format("%s [<option>...] ", program),
                    "Example:",
                    format("%s --iter=10000 -N5 100,2", program),
                    "",
                    "<option>:",
                    ].join("\n"),
                    main_args.options);
            return 0;
        }

        if (exists(opts.path)) {
            rmdirRecurse(opts.path);
        }
        mkdirRecurse(opts.path);

        int[] weights = args[1].ifThrown("100,5,100,100,100")
            .split(",").map!(n => n.to!int).array;

        if (!opts.number_of_nodes.isinit) {
            weights.length = opts.number_of_nodes;
            weights.filter!(w => w == 0)
                .each!((ref w) => w = 100);
        }
        opts.number_of_nodes = cast(uint) weights.length;

        import tagion.utils.pretend_safe_concurrency : register, thisTid;

        register("run_fiber_epoch", thisTid);
        NewTestRefinement.continue_on_error=opts.continue_on_error;
        auto hashgraph_fiber_feature = automation!(run_fiber_epoch);
        hashgraph_fiber_feature.RunPassiveFastHashgraph(opts, weights);
        hashgraph_fiber_feature.run;
    }
    catch (Exception e) {
        error(e);

        return 1;
    }
    return 0;
}

@safe @Scenario("Run passive fast hashgraph",
        [])
class RunPassiveFastHashgraph {
    string[] node_names;
    //string module_path;
    TestNetworkT!NewTestRefinement network;
    //uint MAX_CALLS;
    //uint number_of_nodes = 5;
    const HashGraphOptions opts;
    int[] weights;

    this(const HashGraphOptions opts, int[] weights) {
        this.opts = opts;
        //this.number_of_nodes = opts.number_of_nodes;
        this.node_names = opts.number_of_nodes.iota.map!(i => format("Node_%02d", i)).array;
        //this.MAX_CALLS = MAX_CALLS;
        this.weights = weights;

        network = new TestNetworkT!(NewTestRefinement)(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 100);
        network.random.seed(opts.seed);
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

        FileMonitorCallbacks[Pubkey] node_callbacks;

        if (!opts.disable_graphfile) {
            foreach (channel, network_fiber; network.networks) {
                const graph_file = buildPath(opts.path, format("%s_graph", network_fiber._hashgraph.name))
                .setExtension(FileExtension.hibon);
                node_callbacks[channel] = new FileMonitorCallbacks(
                        graph_file,
                        opts.number_of_nodes,
                        cast(Pubkey[]) network.channels);
            }
        }
        while (NewTestRefinement.last_epoch < opts.max_epochs) {
            size_t channel_number;
            if (NewTestRefinement.epochs.length > 0) {
                channel_number = rnd.dice(weights);
            }
            else {
                channel_number = network.random.value(0, network.channels.length);
            }
            network.current = Pubkey(network.channels[channel_number]);
            auto current = network.networks[network.current];
            if (!node_callbacks.empty) { 
                Event.callbacks = node_callbacks[network.current];
            }
            (() @trusted { current.call; })();
            i++;
        }
        sw.stop;
        foreach(channel, network_fiber; network.networks) {
            const statistic_file=buildPath(opts.path, format("%s_statistic", network_fiber._hashgraph.name))
        .setExtension(FileExtension.hibon);
            statistic_file.fwrite(network_fiber._hashgraph.statistics);
        }
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
