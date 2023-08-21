module tagion.testbench.services.epoch_creator;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.utils.pretend_safe_concurrency;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.services.epoch_creator;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.Types : Pubkey;
import std.algorithm;
import std.array;

import std.stdio;

import core.time;

enum feature = Feature(
            "EpochCreator service",
            [
        "This service is responsbile for resolving the Hashgraph and producing a consensus ordered list of events, an Epoch."
]);

alias FeatureContext = Tuple!(
        SendPayloadAndCreateEpoch, "SendPayloadAndCreateEpoch",
        FeatureGroup*, "result"
);


@safe @Scenario("Send payload and create epoch",
        [])
class SendPayloadAndCreateEpoch {
    // immutable(EpochCreatorOptions) epoch_creator_options = EpochCreatorOptions(1000, 5, 5);
    struct Node {
        SecureNet net;
        string name;
         EpochCreatorOptions opts;   
    }
    Node[] nodes;

    this() {
        //empty


        foreach(i; 0..5) {

            immutable name = format("NODE-%s", i);
            auto net = new StdSecureNet();
            net.generateKeyPair(name);
            nodes ~= Node(net, name, EpochCreatorOptions(1000, 5, 5));            
        }
    }

    @Given("I have 5 nodes and start them in mode0")
    Document mode0() @trusted {

        Pubkey[] pkeys = nodes.map!(n => n.net.pubkey).array;
        
    
        ActorHandle!EpochCreatorService[] handles;

        foreach(n; nodes) {
            handles ~= spawn!EpochCreatorService(
                cast(immutable) n.name,
                cast(immutable) n.opts,
                cast(immutable) n.net,
                cast(immutable(Pubkey[])) pkeys,
            );
        }    

        // // auto net = new StdSecureNet();
        // // immutable passphrase = "wowo";
        // // net.generateKeyPair(passphrase);

        // // auto net2 = new StdSecureNet();
        // // immutable passphrase2 = "wowo2";
        // // net2.generateKeyPair(passphrase);
        // // immutable pkeys = [net.pubkey, net2.pubkey];

        // auto epochhandle = spawn!EpochCreatorService(
        //         "wowo",
        //         epoch_creator_options,
        //         cast(immutable) net,
        //         pkeys,
        // );

        check(waitforChildren(Ctrl.ALIVE, 10.seconds), "The node did not start");

        return result_ok;
    }

    @When("i sent a payload to node0")
    Document node0() {
        return Document();
    }

    @Then("all the nodes should create an epoch containing the payload")
    Document payload() {
        return Document();
    }

}
