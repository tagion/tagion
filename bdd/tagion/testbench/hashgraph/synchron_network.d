module tagion.testbench.hashgraph.synchron_network;
// Default import list for bdd
import core.sys.posix.sys.resource;
import std.algorithm;
import std.array;
import std.array;
import std.conv;
import std.datetime;
import std.exception;
import std.format;
import std.functional : toDelegate;
import std.path : buildPath;
import std.path : extension, setExtension;
import std.range;
import std.stdio;
import std.typecons : Tuple;
import tagion.basic.Types : FileExtension;
import tagion.basic.Types;
import tagion.basic.basic;
import tagion.behaviour;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Refinement;
import tagion.hashgraphview.Compare;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.testbench.hashgraph.hashgraph_test_network;
import tagion.testbench.tools.Environment;
import tagion.utils.Miscellaneous : cutHex;

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
    uint MAX_CALLS;
    this(string[] node_names, const uint calls, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
        MAX_CALLS = cast(uint) node_names.length * calls;
    }

    bool coherent;

    @Given("i have a HashGraph TestNetwork with n number of nodes")
    Document nodes() {
        writefln("getting rlimit");
        rlimit limit;
        (() @trusted { getrlimit(RLIMIT_STACK, &limit); })();
        writefln("RESOURCE LIMIT = %s", limit);

        int[] node_graphs;
        foreach(n; node_names){
            node_graphs ~= 0;
        }
        network = new TestNetwork(node_names, node_graphs, 0);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);
        writeln(network.random);

        network.global_time = SysTime.fromUnixTime(1_614_355_286);

        return result_ok;
    }

    @When("the network has started")
    Document started() {

        foreach (channel; network.channels) {
            auto current = network.networks[channel];
            (() @trusted { current.call; })();
        }
        return result_ok;

    }

    @When("all nodes are sending ripples")
    Document ripples() {
        foreach (i; 0 .. MAX_CALLS) {
            const channel_number = network.random.value(0, network.channels.length);
            const channel = network.channels[channel_number];
            auto current = network.networks[channel];
            (() @trusted { current.call; })();

            // printStates(network);
            if (network.allInGraph) {
                coherent = true;
                break;
            }
        }

        return result_ok;
    }

    @When("all nodes are coherent")
    Document _coherent() {
        check(coherent, "Nodes not coherent");
        return result_ok;
    }

    @Then("wait until the first epoch")
    Document epoch() @trusted {
        {
            uint i = 0;
            while (i < MAX_CALLS) {

                const channel_number = network.random.value(0, network.channels.length);
                network.current = Pubkey(network.channels[channel_number]);
                auto current = network.networks[network.current];
                (() @trusted { current.call; })();

                if (i % 1000 == 0) {
                    writefln("call %s", i);
                }
                // if (network.epoch_events.length == node_names.length) {
                //     // all nodes have created at least one epoch
                //     break;
                // }
                // printStates(network);
                i++;
            }
            check(TestRefinement.epoch_events.length == node_names.length,
                    format("Max calls %d reached, not all nodes have created epochs only %d",
                    MAX_CALLS, TestRefinement.epoch_events.length));
        }

        // compare ordering
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
        foreach (i, compare_epoch; TestRefinement.epoch_events.byKeyValue.front.value) {
            auto compare_events = compare_epoch
                .events
                .map!(e => cast(Buffer) e.event_package.fingerprint)
                .array;
            writefln("comparing epoch %s", i);
            auto compare_round_fingerprint = hashLastDecidedRound(compare_epoch.decided_round);

            // compare_events.sort!((a,b) => a < b);
            // compare_events.each!writeln;
            // writefln("%s", compare_events.map!(f => f.cutHex));
            foreach (channel_epoch; TestRefinement.epoch_events.byKeyValue) {
                // writefln("epoch: %s", i);
                if (channel_epoch.value.length - 1 < i) {
                    break;
                }
                auto events = channel_epoch.value[i]
                    .events
                    .map!(e => cast(Buffer) e.event_package.fingerprint)
                    .array;
                auto channel_round_fingerprint = hashLastDecidedRound(compare_epoch.decided_round);
                // events.sort!((a,b) => a < b);

                // writefln("%s", events.map!(f => f.cutHex));
                // events.each!writeln;
                // writefln("channel %s time: %s", channel_epoch.key.cutHex, channel_epoch.value[i].epoch_time);

                check(compare_events.length == events.length, "event_packages not the same length");

                const sameEvents = equal(compare_events.sort, events.sort);
                check(sameEvents, "events lists does not contain same events");

                const isSame = equal(compare_events, events);
                // writefln("isSame: %s", isSame);
                check(isSame, "event_packages not the same");

                const sameRoundFingerprints = equal(compare_round_fingerprint.fingerprints, channel_round_fingerprint
                        .fingerprints);
                check(sameRoundFingerprints, "round fingerprints not the same");
            }
        }

        return result_ok;
    }

    @Then("stop the network")
    Document _network() {
        Pubkey[string] node_labels;
        import tagion.hashgraphview.EventView;
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
