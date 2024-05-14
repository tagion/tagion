module tagion.testbench.services.node_interface;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import core.time;

import std.stdio;
import tagion.actor;
import tagion.services.nodeinterface;
import tagion.services.messages;
import tagion.script.namerecords;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.tools.Basic;
import tagion.gossip.AddressBook;
import tagion.hibon.HiBON;
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

    this() {
        auto _a_net = new StdSecureNet();
        _a_net.generateKeyPair("A");
        a_net = _a_net;
        auto _b_net = new StdSecureNet();
        _b_net.generateKeyPair("B");
        b_net = _b_net;
    }

    @Given("i have 2 listening node interfaces")
    Document interfaces() @trusted {
        thisActor.task_name = "JumboJet";

        { // A
            immutable opts = NodeInterfaceOptions(node_address: "abstract://nodeinterface_a", bufsize: 256);
            shared _net = cast(shared(StdSecureNet))(a_net.clone());
            immutable nnr = new NetworkNodeRecord(a_net.pubkey, opts.node_address);
            addressbook.set(nnr);
            a_handle = _spawn!NodeInterfaceService_("interface_a", opts, _net, thisActor.task_name);
        }
        { // B
            immutable opts = NodeInterfaceOptions(node_address: "abstract://nodeinterface_b", bufsize: 512);
            shared _net = cast(shared(StdSecureNet))(b_net.clone());
            immutable nnr = new NetworkNodeRecord(b_net.pubkey, opts.node_address);
            addressbook.set(nnr);
            b_handle = _spawn!NodeInterfaceService_("interface_b", opts, _net, thisActor.task_name);
        }

        check(waitforChildren(Ctrl.ALIVE), "No all node_interfaces became alive");

        return result_ok;
    }

    @Then("i send messages back and forth 3 times")
    Document b() {
        { // A -> B
            const sender = HiRPC(a_net).action("froma1", ResultOk());
            a_handle.send(NodeSend(), b_net.pubkey, Document(sender.toDoc));
            receiveOnlyTimeout(1.seconds, (ReceivedWavefront _, const(Document) doc) { writeln("received ", doc.toPretty);});
        }

        { // B -> A
            const sender = HiRPC(b_net).action("fromb2", ResultOk());
            b_handle.send(NodeSend(), a_net.pubkey, Document(sender.toDoc));
            receiveOnlyTimeout(1.seconds, (ReceivedWavefront _, const(Document) doc) { writeln("received ", doc.toPretty);});
        }

        { // A -> B
            const sender = HiRPC(a_net).action("froma3", ResultOk());
            a_handle.send(NodeSend(), b_net.pubkey, Document(sender.toDoc));
            receiveOnlyTimeout(1.seconds, (ReceivedWavefront _, const(Document) doc) { writeln("received ", doc.toPretty);});
        }

        return result_ok;
    }

    @Then("i send message greater than the max buffer size")
    Document size() {
        { // B -> A
            // An array larger than A's buffer size and less than B's
            immutable large_arr = new ubyte[](316);
            auto hibon = new HiBON;
            hibon["a"] = large_arr;
            const sender = HiRPC(b_net).action("fromb4", Document(hibon));
            b_handle.send(NodeSend(), a_net.pubkey, Document(sender.toDoc));

            bool received = receiveTimeout(1.seconds, (ReceivedWavefront _, const(Document) doc) { writeln(doc.toPretty);});
            check(!received, "Should not receive anything");
        }
        return result_ok;
    }
}
