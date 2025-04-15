module tagion.testbench.hashgraph.hashgraph_mirror;

import std.typecons;
import std.algorithm;
import std.range;
import std.format;
import std.random;
import std.stdio;

import tagion.behaviour;
import tagion.hibon.Document;
import tagion.crypto.Types;
import tagion.tools.Basic;
import tagion.testbench.hashgraph.hashgraph_test_network;
import tagion.testbench.tools.Environment;

mixin Main!(_main);

int _main(string[] args) {
    auto feature = automation!(mixin(__MODULE__));
    /* feature.RunFollowNetwork(); */
    feature.run;

    return 0;
}

enum feature = Feature(
            "Check that we can run a graph that mirrors a network without participating in it",
            []);

alias FeatureContext = Tuple!(
        RunFollowNetwork, "RunFollowNetwork ",
        FeatureGroup*, "result"
);

@Scenario("Run Follow network",
        [])
class RunFollowNetwork {

    TestNetwork network;
    uint number_of_nodes = 200;

    @Given("I have a hashgraph network")
    Document f1() {
        network = new TestNetwork(number_of_nodes.iota.map!(i => format("Node_%02d", i)).array);
        network.random = Random(env.getSeed);

        foreach(_; 0 .. 100_000) {
            if(TestRefinement.last_epoch >= 2) {
                break;
            }

            size_t channel_number = uniform(0, number_of_nodes, network.random);
            network.current = Pubkey(network.channels[channel_number]);
            auto current = network.networks[network.current];

            (() @trusted { current.call; })();
        }
        writeln("Epoch ", TestRefinement.last_epoch);

        return result_ok;
    }

    @When("I set a node to follow the network graph")
    Document f2() {
        return Document();
    }

    @Then("It should be correctly mirrored")
    Document f3() {
        return Document();
    }

}
