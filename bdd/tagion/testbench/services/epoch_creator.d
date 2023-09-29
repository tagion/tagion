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
import tagion.services.options;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.Types : Pubkey;
import std.algorithm;
import std.array;
import tagion.utils.Miscellaneous : cutHex;
import tagion.services.messages;
import tagion.logger.Logger;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import std.range : empty;
import tagion.hashgraph.HashGraphBasic;
import tagion.services.monitor;
import tagion.services.options : NetworkMode;

import std.stdio;

import core.time;
import core.thread;
import tagion.gossip.AddressBook : addressbook, NodeAddress;

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
    struct Node {
        SecureNet net;
        string name;
        EpochCreatorOptions opts;
        MonitorOptions monitor_opts;
    }

    immutable(size_t) number_of_nodes;

    Node[] nodes;
    ActorHandle!EpochCreatorService[] handles;
    Document send_payload;

    this(EpochCreatorOptions epoch_creator_options, MonitorOptions monitor_opts, immutable size_t number_of_nodes) {
        import tagion.services.options;

        this.number_of_nodes = number_of_nodes;

        addressbook.number_of_active_nodes = number_of_nodes;
        foreach (i; 0 .. number_of_nodes) {
            immutable prefix = format("Node_%s", i);
            immutable task_names = TaskNames(prefix);
            auto net = new StdSecureNet();
            net.generateKeyPair(task_names.epoch_creator);
            writefln("node task name %s", task_names.epoch_creator);

            auto monitor_local_options = monitor_opts;
            monitor_local_options.enable = i == 1 ? true : false;
            nodes ~= Node(net, task_names.epoch_creator, epoch_creator_options, monitor_local_options);
            addressbook[net.pubkey] = NodeAddress(task_names.epoch_creator);
        }

    }

    @Given("I have 5 nodes and start them in mode0")
    Document mode0() @trusted {
        register("epoch_creator_tester", thisTid);

        foreach (n; nodes) {
            handles ~= spawn!EpochCreatorService(
                    cast(immutable) n.name,
                    cast(immutable) n.opts,
                    NetworkMode.INTERNAL,
                    number_of_nodes,
                    cast(immutable) n.net,
                    cast(immutable) n.monitor_opts,
                    TaskNames(),
            );
        }

        waitforChildren(Ctrl.ALIVE);
        //    writefln("Wait 1 sec");
        Thread.sleep(20.seconds);

        return result_ok;
    }

    @When("i sent a payload to node0")
    Document node0() @trusted {

        import tagion.hibon.HiBON;
        import tagion.hibon.Document;

        auto h = new HiBON;
        h["node0"] = "TEST PAYLOAD";
        send_payload = Document(h);
        writefln("SENDING TEST DOC");
        handles[1].send(Payload(), const Document(h));

        return result_ok;
    }

    @Then("all the nodes should create an epoch containing the payload")
    Document payload() {
        writefln("BEFORE TIMEOUT");
        log.registerSubscriptionTask("epoch_creator_tester");

        submask.subscribe("epoch_creator/epoch_created");

        bool stop;
        const max_attempts = 10;
        uint counter;
        do {
            const received = receiveOnly!(Topic, string, immutable(EventPackage*)[]);
            const epoch = received[2];
            writefln("received epoch %s%s", epoch, epoch.length);

            if (epoch.length > 0) {
                check(epoch.length == 1, format("should only have received one event got %s", epoch.length));

                const received_payload = epoch[0].event_body.payload;
                check(received_payload == send_payload, "Payloads not the same");
                stop = true;
            }
            counter++;

        }
        while (!stop || counter < max_attempts);
        check(stop, "no epoch found");

        foreach (handle; handles) {
            handle.send(Sig.STOP);
        }

        waitforChildren(Ctrl.END);
        return result_ok;
    }

}
