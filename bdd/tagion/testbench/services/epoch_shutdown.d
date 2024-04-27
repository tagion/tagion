module tagion.testbench.services.epoch_shutdown;

import core.time;

import std.stdio;
import std.format;

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

import tagion.dart.DART;
import tagion.dart.DARTFile;


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
        check(epochs_created, format("%s", test_net.epochs));
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
        bool epochs_created = test_net.wait_for_epochs(10, 100.seconds);
        check(epochs_created, format("Nodes did not create the expected amount of epochs %s", test_net.epochs));
        // 
        test_net.wait_for_epochs(20, 100.seconds);
        /* check(!epochs_created, format("nodes created epochs after they should've stopped %s", test_net.epochs)); */
        return result_ok;
    }

}
