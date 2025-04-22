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

import core.memory;
import core.thread;

import tagion.hashgraph.RefinementInterface;
import tagion.hashgraph.Event;
import tagion.gossip.GossipNet;
import tagion.utils.StdTime;
import tagion.crypto.SecureNet;
import tagion.hashgraph.HashGraph;
import tagion.utils.convert;

class MirrorNodeFiber : Fiber {
    HashGraph _hashgraph;
    TestGossipNet authorising;
    //immutable(string) name;
    @trusted
    this(HashGraph h, GossipNet authorising, const(ulong) stacksize = pageSize * Fiber.defaultStackPages) nothrow
    {
        super(&run, stacksize);
        _hashgraph = h;
        this.authorising = authorising;
    }

    const(HashGraph) hashgraph() const pure nothrow {
        return _hashgraph;
    }

    sdt_t time() {
        const systime = global_time + uniform(timestep.MIN, timestep.MAX, random).msecs;
        const sdt_time = sdt_t(systime.stdTime);
        return sdt_time;
    }

    private void run() {
        uint count;
        bool stop;

        const(Document) payload() {
            if (!_hashgraph.refinement.queue.empty) {
                return _hashgraph.refinement.queue.read;
            }
            auto h = new HiBON;
            h["node"] = format("%s-%d", _hashgraph.name, count);
            count++;
            return Document(h);
        }

        void wavefront(
                const HiRPC.Receiver received,
                lazy const(sdt_t) time) {

            const response = _hashgraph.wavefront_response(received, time, payload());
            if (!response.isError) {
                authorising.send(received.pubkey, response);
            }
        }

        while (!stop) {
            while (!authorising.empty(_hashgraph.channel)) {
                /* if (current !is Pubkey.init && TestGossipNet.online_states !is null && !TestGossipNet.online_states[current]) { */
                /*     (() @trusted { yield; })(); */
                /* } */

                const received = _hashgraph.hirpc.receive(
                        authorising.receive(_hashgraph.channel));
                wavefront(received, time);
            }
            (() @trusted { yield; })();
            const init_tide = uniform(0, 2, random) is 1;
            if (init_tide) {
                authorising.send(
                        _hashgraph.select_channel, _hashgraph.create_init_tide(payload(), time));
            }
        }
    }
}

MirrorNodeFiber createMirrorNode(TestNetwork network, Refinement refinement, immutable(ulong) N, const(string) name,
            int scrap_depth = 0) {
        immutable passphrase = format("very secret %s", name);
        auto net = new StdSecureNet();
        net.generateKeyPair(passphrase);
        refinement.queue = new PayloadQueue;
        auto h = new HashGraph(N, net, refinement, network.authorising, name);
        h.mirror_mode = true;
        h.scrap_depth = scrap_depth;
        writefln("Adding Node: %s with %s", name, net.pubkey.cutHex);
        /* networks[net.pubkey] = new FiberNetwork(h, pageSize * 1024); */
        network.authorising.add_channel(net.pubkey);
        /* TestGossipNet.online_states[net.pubkey] = true; */
        return new MirrorNodeFiber(h, network.authorising, pageSize * 1024);
}


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
        createMirrorNode(network, new TestRefinement, number_of_nodes, "follow_graph1");

        return result_ok;
    }

    @Then("It should be correctly mirrored")
    Document f3() {
        return Document();
    }

}
