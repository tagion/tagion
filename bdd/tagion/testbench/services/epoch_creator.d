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
import tagion.dart.DARTOptions;

import std.stdio;

import core.time;
import core.thread;
import tagion.gossip.AddressBook;

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
    immutable(EpochCreatorOptions) epoch_creator_options; // = EpochCreatorOptions(1000, 5, 0);

    this(immutable(EpochCreatorOptions) epoch_creator_options) {
        import tagion.services.options;

        this.epoch_creator_options = epoch_creator_options;
        //EpochCreatorOptions xxx = epoch_creator_options;
        addressbook.number_of_active_nodes = epoch_creator_options.nodes;
        foreach (i; 0 .. epoch_creator_options.nodes) {
            EpochCreatorOptions local_opts = epoch_creator_options;
            immutable prefix = format("Node_%s", i);
            setTaskPrefix(local_opts, prefix);
            immutable opts = local_opts;
            auto net = new StdSecureNet();
            net.generateKeyPair(opts.task_name);
            nodes ~= Node(net, opts.task_name, opts);
            addressbook[net.pubkey] = NodeAddress(format("address %s", i), DARTOptions.init, 0);
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
        foreach (n; nodes) {
            handles ~= spawn!EpochCreatorService(
                    cast(immutable) n.name,
                    cast(immutable) n.opts,
                    cast(immutable) n.net,
            );
        }
        waitforChildren(Ctrl.STARTING);
        /*
        handles.each!(h => pkeys ~= receiveOnly!Pubkey);
        check(pkeys.length == handles.length && pkeys.length == epoch_creator_options.nodes, "not all pkeys added");
        writefln("owner received pkeys");

        
        foreach (i, handle; handles) {
            foreach (pkey; pkeys) {
                writefln("BEFORE SEND %s", i);
                handle.send(pkey);
                // Thread.sleep(1.msecs);
                writefln("AFTER SEND %s", i);
            }

            // pkeys.each!(p => handle.send(p));
            writefln("send node %d %d pkeys", i, pkeys.length);
            receiveOnly!(AddedChannels);
        }

        handles.each!(h => h.send(Msg!"BEGIN"()));
*/
        waitforChildren(Ctrl.ALIVE);
        //    writefln("Wait 1 sec");
        //      Thread.sleep(1.seconds);

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

        return result_ok;
    }

    @When("i sent a payload to node0")
    Document node0() {

        return Document();
    }

    @Then("all the nodes should create an epoch containing the payload")
    Document payload() {

        // import core.thread.threadbase : thread_joinAll;
        // (() @trusted => thread_joinAll())();

        foreach (handle; handles) {
            handle.send(Sig.STOP);
        }

        waitforChildren(Ctrl.END);
        return Document();
    }

}
