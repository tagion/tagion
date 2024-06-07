module tagion.testbench.services.epoch_shutdown;

import core.time;

import std.stdio;
import std.format;
import std.exception;
import std.range;

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import tagion.utils.pretend_safe_concurrency;
import tagion.logger.Logger;
import tagion.hashgraph.Refinement;

import tagion.actor;
import tagion.services.messages;
import tagion.testbench.utils.create_network;
import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;
import tagion.script.common;

import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.DARTBasic;
import tagion.dart.DARTcrud;
import tagion.wave.common;


enum feature = Feature(
            "epoch shutdown",
            []);

mixin Main!_main;

int _main(string[] args) {
    auto test_net = new TestNetwork();

    auto epoch_shutdown_feature = automation!(mixin(__MODULE__));
    epoch_shutdown_feature.StoppingAllNodesAtASpecificEpoch(test_net);
    epoch_shutdown_feature.run();

    return 0;
}

alias FeatureContext = Tuple!(
        StoppingAllNodesAtASpecificEpoch, "StoppingAllNodesAtASpecificEpoch",
        FeatureGroup*, "result"
);

@safe @Scenario("Stopping all nodes at a specific epoch", [])
class StoppingAllNodesAtASpecificEpoch {
    TestNetwork test_net;

    enum SHUTDOWN_EPOCH = 10;

    this(TestNetwork test_net) {
        this.test_net = test_net;
    }

    Tid net_tid;

    @Given("I have a running network producing epochs")
    Document epochs() {
        test_net.create_files();
        net_tid = test_net.start_network();
        thisActor.task_name = "epoch_shutdown";
        log.registerSubscriptionTask("epoch_shutdown");
        submask.subscribe(StdRefinement.epoch_created);

        writeln("waiting for epoch");
        bool epochs_created = test_net.wait_for_epochs(1, 100.seconds);
        enforce(epochs_created, format("%s", test_net.epochs));
        writeln("waiting end");

        return result_ok;
    }

    @When("I send an epoch shutdown signal")
    Document signal() {
        // Shutdown when all nodes have reached 10 epochs
        net_tid.send(EpochShutdown(), long(10));

        return result_ok;
    }

    @Then("the network should stop at the specified epoch")
    Document epoch() {
        bool epochs_created = test_net.wait_for_epochs(SHUTDOWN_EPOCH, 100.seconds);
        enforce(epochs_created, format("Nodes did not create the expected amount of epochs %s", test_net.epochs));
        // We wait for a few more epochs, just to be sure that all consensus epochs are reached
        test_net.wait_for_epochs(SHUTDOWN_EPOCH + 10, 100.seconds);

        SecureNet net = new StdSecureNet();
        net.generateKeyPair(__MODULE__);
        const hirpc = HiRPC(net);

        foreach(opt; test_net.node_opts) {
            const node_name = opt.task_names.supervisor;
            auto db = new DART(net, opt.dart.dart_path);
            TagionHead head = getHead(db, net);
            enforce(head.current_epoch == SHUTDOWN_EPOCH, format("%s Wrong head %s", node_name, head.current_epoch));

            const locked_indices = lockedArchiveIndices(iota(SHUTDOWN_EPOCH, SHUTDOWN_EPOCH + 10), net);
            const sender = dartRead(locked_indices, hirpc);
            const receiver = hirpc.receive(sender);
            auto response = db(receiver);
            auto locked_archives_recorder = db.recorder(response.result);
            enforce(locked_archives_recorder[].empty, format("%s locked archives %s", node_name, locked_archives_recorder[].walkLength));

            /* opt.replicator. */
        }

        return result_ok;
    }
}
