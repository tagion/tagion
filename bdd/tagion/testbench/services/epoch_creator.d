module tagion.testbench.services.epoch_creator;
// Default import list for bdd
import core.thread;
import core.time;
import std.algorithm;
import std.array;
import std.format;
import std.range : empty;
import std.stdio;
import std.typecons : Tuple;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.behaviour;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.gossip.AddressBook : addressbook;
import tagion.hashgraph.HashGraphBasic;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.services.epoch_creator;
import tagion.services.messages;
import tagion.services.options;
import tagion.services.options : NetworkMode;
import tagion.script.namerecords : NetworkNodeRecord;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.utils.Miscellaneous : cutHex;
import tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "EpochCreator service",
            [
        "This service is responsible for resolving the Hashgraph and producing a consensus ordered list of events, an Epoch."
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
    }

    uint number_of_nodes;

    Node[] nodes;
    ActorHandle[] handles;
    Document send_payload;

    this(EpochCreatorOptions epoch_creator_options, uint number_of_nodes) {
        import tagion.services.options;

        this.number_of_nodes = number_of_nodes;

        foreach (i; 0 .. number_of_nodes) {
            immutable prefix = format("Node_%s", i);
            immutable task_names = TaskNames(prefix);
            auto net = new StdSecureNet();
            net.generateKeyPair(task_names.epoch_creator);
            shared shared_net = (() @trusted => cast(shared) net)();
            scope (exit) {
                net = null;
            }
            writefln("node task name %s", task_names.epoch_creator);
            nodes ~= Node(shared_net, task_names.epoch_creator, epoch_creator_options);
            addressbook.set(new NetworkNodeRecord(net.pubkey, task_names.epoch_creator));
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

        import tagion.hibon.Document;
        import tagion.hibon.HiBON;

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
            const received = receiveOnlyTimeout!(LogInfo, const(Document))(27.seconds);
            check(received[0].symbol_name.canFind("epoch_successful"), "Event should have been epoch_successful");
            const epoch = received[1];

            import tagion.hashgraph.Refinement : FinishedEpoch;
            import tagion.hibon.HiBONRecord;

            check(epoch.isRecord!FinishedEpoch, "received event should be an FinishedEpoch record");
            const events = FinishedEpoch(epoch).events;
            writefln("Received epoch %s \n event_length %s", epoch.toPretty, events.length);

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
