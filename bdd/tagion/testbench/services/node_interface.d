module tagion.testbench.services.node_interface;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.stdio;
import tagion.actor;
import tagion.services.nodeinterface;
import tagion.services.messages;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.tools.Basic;
/* import tagion.utils.pretend_safe_concurrency; */

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
            immutable opts = NodeInterfaceOptions(node_address: "abstract://nodeinterface_a");
            shared _net = cast(shared(StdSecureNet))(a_net.clone());
            a_handle = _spawn!NodeInterfaceService_("node_interface_a", opts, _net, thisActor.task_name);
        }
        { // B
            immutable opts = NodeInterfaceOptions(node_address: "abstract://nodeinterface_b");
            shared _net = cast(shared(StdSecureNet))(b_net.clone());
            b_handle = _spawn!NodeInterfaceService_("node_interface_b", opts, _net, thisActor.task_name);
        }

        check(waitforChildren(Ctrl.ALIVE), "No all node_interfaces became alive");

        return result_ok;
    }

    @When("i send a message from A to B")
    Document b() {
        const sender = HiRPC(a_net).action("comms", ResultOk());
        a_handle.send(NodeSend(), b_net.pubkey, Document(sender.toDoc));

        return result_ok;
    }

    @Then("B should receive the message")
    Document message() {
        receiveOnlyTimeout((ReceivedWavefront _, Document doc) { writeln("received ", doc.toPretty);});

        /* receive_handle.send(ReceivedWavefront(), doc); */

        return result_ok;
    }

}
