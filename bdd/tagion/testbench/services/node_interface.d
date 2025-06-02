module tagion.testbench.services.node_interface;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.time;

import std.stdio;
import std.range;

import tagion.actor;
import tagion.services.nodeinterface;
import tagion.services.socket_nodeinterface;
import tagion.services.messages;
import tagion.services.tasknames;
import tagion.script.namerecords;
import tagion.script.standardnames;
import tagion.script.methods;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.tools.Basic;
import tagion.gossip.AddressBook;
import tagion.hibon.HiBON;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.pretend_safe_concurrency;

import tagion.testbench.actor.util;

mixin Main!_main;

int _main(string[] args) {
    auto nodeinterface_feature = automation!(mixin(__MODULE__));
    nodeinterface_feature.PubkeyASendsAMessageToPubkeyB();
    nodeinterface_feature.run();

    return 0;
}

enum feature = Feature("Nodeinterface service", []);

alias FeatureContext = Tuple!(
        PubkeyASendsAMessageToPubkeyB, "PubkeyASendsAMessageToPubkeyB",
        FeatureGroup*, "result"
);

@safe @Scenario("pubkey A sends a message to pubkey B", [])
class PubkeyASendsAMessageToPubkeyB {

    const(SecureNet) a_net;
    const(SecureNet) b_net;

    ActorHandle a_handle;
    ActorHandle b_handle;

    immutable(NodeInterfaceOptions) opts_a;
    immutable(NodeInterfaceOptions) opts_b;

    shared(AddressBook) addressbook;

    this() {
        this.addressbook = new shared(AddressBook);
        auto _a_net = createSecureNet;
        _a_net.generateKeyPair("A");
        a_net = _a_net;
        auto _b_net = createSecureNet;
        _b_net.generateKeyPair("B");
        b_net = _b_net;

        opts_a = NodeInterfaceOptions(node_address: "abstract://nodeinterface_a", bufsize: 256);
        opts_b = NodeInterfaceOptions(node_address: "abstract://nodeinterface_b", bufsize: 512);
    }

    @Given("i have 2 listening node interfaces")
    Document interfaces() @trusted {
        thisActor.task_name = "JumboJet";
        TaskNames tn;
        tn.epoch_creator = thisActor.task_name;

        { // A
            tn.node_interface = "interface_a";
            tn.event_listener = "ev_a";
            shared _net = cast(shared(StdSecureNet))(a_net.clone());
            immutable nnr = new NetworkNodeRecord(a_net.pubkey, opts_a.node_address);
            addressbook.set(nnr);
            a_handle = _spawn!NodeInterface(tn.node_interface, opts_a.node_address, addressbook, tn);
        }
        { // B
            tn.node_interface = "interface_b";
            tn.event_listener = "ev_b";
            shared _net = cast(shared(StdSecureNet))(b_net.clone());
            immutable nnr = new NetworkNodeRecord(b_net.pubkey, opts_b.node_address);
            addressbook.set(nnr);
            b_handle = _spawn!NodeInterface(tn.node_interface, opts_b.node_address, addressbook, tn);
        }

        check(waitforChildren(Ctrl.ALIVE), "No all node_interfaces became alive");

        return result_ok;
    }

    @Then("i send messages back and forth 3 times")
    Document b() {
        WavefrontReq reqa;
        WavefrontReq reqb;
        { // A -> B
            Wavefront wave;
            wave.state = ExchangeState.TIDAL_WAVE;
            const hirpc = HiRPC(a_net);
            const sender = wavefront(wave, hirpc);
            a_handle.send(WavefrontReq(), b_net.pubkey, sender.toDoc);
            receiveOnlyTimeout(2.seconds, (WavefrontReq req, Document doc) {
                reqa = req;
                writeln("received ", doc.toPretty);
            });
        }

        { // B -> A
            Wavefront wave;
            wave.state = ExchangeState.FIRST_WAVE;
            const sender = wavefront(wave, HiRPC(b_net));
            writeln("reqa: ", reqa.tid);
            send(reqa.tid, WavefrontReq(), a_net.pubkey, sender.toDoc);
            receiveOnlyTimeout(2.seconds, (WavefrontReq req, Document doc) {
                reqb = req;
                writeln("received ", doc.toPretty);
            });
        }

        { // A -> B
            Wavefront wave;
            wave.state = ExchangeState.SECOND_WAVE;
            const hirpc = HiRPC(a_net);
            // End communication by a result
            const tmp_receiver = hirpc.receive(hirpc.action("wavefront", wave));
            const sender = hirpc.result(tmp_receiver, Document());
            send(reqb.tid, WavefrontReq(), b_net.pubkey, sender.toDoc);
            receiveOnlyTimeout(2.seconds, (WavefrontReq _, Document doc) { writeln("received ", doc.toPretty); });
        }

        return result_ok;
    }

    @Then("i send message greater than the max buffer size")
    Document size() @trusted {
        { // B -> A
            // We construct a fake wavefront with a big nonce
            auto wave = new HiBON;
            wave["$@"] = "Wavefront";
            wave[StdNames.state] = ExchangeState.NONE;

            // An array larger than A's buffer size and less than B's
            import std.random;

            auto rnd = Random(42);
            wave["nonce"] = cast(immutable(ubyte)[]) rnd.take((opts_a.bufsize + 12) / uint.sizeof).array;

            const sender = HiRPC(b_net).action("fromb4", Document(wave));
            b_handle.send(WavefrontReq(), cast(Pubkey) a_net.pubkey, sender.toDoc);

            bool received = receiveTimeout(1.seconds, (WavefrontReq _, Document doc) { writeln(doc.toPretty); });
            check(!received, "Should not receive anything");
        }
        return result_ok;
    }

    @Then("I try to send to a node which can't be reached")
    Document reached() {
        auto c_net = createSecureNet;
        c_net.generateKeyPair("C");

        immutable nnr = new NetworkNodeRecord(c_net.pubkey, "abstract://nodeinterface_c");
        addressbook.set(nnr);

        const sender = HiRPC(a_net).action("froma5", Wavefront());
        a_handle.send(WavefrontReq(), c_net.pubkey, sender.toDoc);

        bool received = receiveTimeout(1.seconds, (WavefrontReq _, Document doc) { writeln(doc.toPretty); });
        check(!received, "Should not receive anything");

        return result_ok;
    }
}
