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
import tagion.logger.LogRecords : LogInfo;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import std.range : empty;
import tagion.hashgraph.HashGraphBasic;
import tagion.services.monitor;
import tagion.services.options : NetworkMode;

import std.stdio;
import std.format;

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
        shared(StdSecureNet) node_net;
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
            shared shared_net = (()@trusted => cast(shared) net)();
            scope(exit) {
                net = null;
            }
            writefln("node task name %s", task_names.epoch_creator);
            auto monitor_local_options = monitor_opts;
            nodes ~= Node(shared_net, task_names.epoch_creator, epoch_creator_options, monitor_local_options);
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
                    n.node_net,
                    cast(immutable) n.monitor_opts,
                    TaskNames(),
            );
        }

        waitforChildren(Ctrl.ALIVE, 15.seconds);

        return result_ok;
    }

    @When("i sent a payload to node0")
    Document node0() @trusted {
        log.registerSubscriptionTask("epoch_creator_tester");

        submask.subscribe("epoch_creator/epoch_created");

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

        bool stop;
        const max_attempts = 30;
        uint counter;
        do {
            const received = receiveOnly!(LogInfo, const(Document));
            check(received[0].symbol_name.canFind("epoch_succesful"), "Event should have been epoch_succesful");
            const epoch = received[1];

            import tagion.hashgraph.Refinement : FinishedEpoch;
            import tagion.hibon.HiBONRecord;

            check(epoch.isRecord!FinishedEpoch, "received event should be an FinishedEpoch record");
            const events = FinishedEpoch(epoch).events;
            writefln("Received epoch %s \n event_length %s", epoch.toPretty,events.length);

            if (events.length == 1) {
                const received_payload = events[0].event_body.payload;
                check(received_payload == send_payload, "Payloads not the same");
                stop = true;
            }
            counter++;
        }
        while (!stop && counter < max_attempts);
        check(stop, "no epoch found");

        foreach (handle; handles) {
            handle.send(Sig.STOP);
        }

        waitforChildren(Ctrl.END);
        return result_ok;
    }

}
