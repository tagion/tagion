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
import tagion.utils.Miscellaneous : cutHex;

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
    ActorHandle!EpochCreatorService[] handles;

    this() {
        //empty


        foreach(i; 0..5) {

            immutable name = format("Node_%s", i);
            auto net = new StdSecureNet();
            net.generateKeyPair(name);
            nodes ~= Node(net, name, EpochCreatorOptions(1000, 5, 5));            
        }
    }

    @Given("I have 5 nodes and start them in mode0")
    Document mode0() @trusted {
        import tagion.options.CommonOptions : setCommonOptions;
        import tagion.prior_services.Options;


        Options opt;
        setDefaultOption(opt);
        setCommonOptions(opt.common);

        // Pubkey[] pkeys = nodes.map!(n => n.net.pubkey).array;
    
        Pubkey[] pkeys;
        foreach(n; nodes) {
            handles ~= spawn!EpochCreatorService(
                cast(immutable) n.name,
                cast(immutable) n.opts,
                cast(immutable) n.net,
            );
        }
        waitforChildren(Ctrl.STARTING);

        foreach(handle; handles) {

            auto p = receiveOnly!Pubkey;
            writefln("owner receive %s", p.cutHex);
            pkeys ~= p;
        }        
        foreach (handle; handles) {
            foreach (pkey; pkeys) {
                writefln("OWNER SEND");
                handle.send(pkey);
            }
        }

        waitforChildren(Ctrl.ALIVE);


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

        foreach( handle; handles) {
            handle.send(Sig.STOP);
        }
        
        waitforChildren(Ctrl.END);
        return Document();
    }

}
