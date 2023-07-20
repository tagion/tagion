
module tagion.testbench.hashgraph.round_fingerprint;

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
import tagion.hashgraphview.Compare;
import tagion.hashgraph.Event;
import std.format;
import std.exception;
import std.conv;
import tagion.hibon.HiBONJSON;
import tagion.utils.Miscellaneous : toHexString;
import tagion.basic.basic;
import std.functional : toDelegate;
import tagion.basic.Types;
import tagion.hashgraph.Refinement;

import std.stdio;


enum feature = Feature(
    "Deterministic round fingerprint", []);

alias FeatureContext = Tuple!(
    SameRoundFingerprintAcrossDifferentNodes, "SameRoundFingerprintAcrossDifferentNodes",
FeatureGroup*, "result"
);


@safe @Scenario("Same round fingerprint across different nodes",
[])

class SameRoundFingerprintAcrossDifferentNodes {

   string[] node_names;
    TestNetwork network;
    string module_path;
    uint MAX_CALLS;
    this(string[] node_names, const(string) module_path) {
        this.node_names = node_names;
        this.module_path = module_path;
        MAX_CALLS = cast(uint) node_names.length * 500;
    }

    bool coherent;
            
@Given("I have a HashGraph TestNetwork with n number of nodes")
Document nodes() {
        rlimit limit;
        (() @trusted { getrlimit(RLIMIT_STACK, &limit); })();

        network = new TestNetwork(node_names);
        network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
        network.random.seed(123456789);

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



    @Then("wait until the first epoch")
    Document epoch() @trusted
    {
        {
            uint i = 0;
            while(i < MAX_CALLS) {
        
                const channel_number = network.random.value(0, network.channels.length);
                network.current = Pubkey(network.channels[channel_number]);
                auto current = network.networks[network.current];
                (() @trusted { current.call; })();
                i++;
            }
            check(TestRefinement.epoch_events.length == node_names.length, 
                format("Max calls %d reached, not all nodes have created epochs only %d", 
                MAX_CALLS, TestRefinement.epoch_events.length));
        }


        
        return result_ok;
    }
@Then("check that the nodes have the same round fingerprint")
Document fingerprint() @trusted
    {   
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

        int minimum_common_round = names.map!(n => hashgraphs[n].rounds.last_decided_round.number).minElement;
        auto ldr1 =   cast(Round)hashgraphs[names[0]].rounds.last_decided_round;
        int r1 = ldr1.number;

        while(r1 > minimum_common_round)
        {
            ldr1 = ldr1.previous;
            r1--;
        }
        const rf1 = StdRefinement.hashLastDecidedRound(ldr1);

        foreach(name; names[1 .. $]) {
            auto ldr2 = cast(Round)hashgraphs[name].rounds.last_decided_round;
            int r2 = ldr2.number;
            while(r2 > minimum_common_round)
            {
                ldr2 = ldr2.previous;
                r2--;
            }
            const rf2 = StdRefinement.hashLastDecidedRound(ldr2);
            const result = equal(rf1.fingerprints, rf2.fingerprints);
            writefln("Do %s and %s round fingerprints agree: %s", names[0], name, result);
            check(result, format("HashGraph %s and %s have different round fingerprints", names[0], name));
        }
        return result_ok;
    }
}
