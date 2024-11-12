module tagion.testbench.testnetwork.godcontract;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    
//    nng_testsuite.testroot = buildPath(env.reporoot, "src", "lib-nngd", "nngd", "nngtests");

    auto feature = automation!(mixin(__MODULE__))();
    //nng_feature.MultithreadedNNGTestSuiteWrapper();

    auto feature_context = feature.run();
    return 0;

}

enum feature = Feature(
            "God Contract for the test network.",
            [
            "This enables to change modify the DART in testnetwork.",
            "The network need to be build with the version=GOD_CONTRACT"
            ]);

alias FeatureContext = Tuple!(
        RequestNetworkRunningInTestmode, "RequestNetworkRunningInTestmode",
        RemoveOneOrMoreOfTheArchivesAddToTheDART, "RemoveOneOrMoreOfTheArchivesAddToTheDART",
        FeatureGroup*, "result"
);

@safe @Scenario("Request network running in test-mode",
        [])
class RequestNetworkRunningInTestmode {

    @Given("that a test network is running.")
    Document running() {
        return Document();
    }

    @When("send a god-contract to add archives to the DART.")
    Document dART() {
        return Document();
    }

    @Then("wait until the a network process a number of epochs")
    Document epochs() {
        return Document();
    }

    @Then("send a dartRead to check if the archives exists")
    Document exists() {
        return Document();
    }

}

@safe @Scenario("Remove one or more of the archives add to the DART",
        [])
class RemoveOneOrMoreOfTheArchivesAddToTheDART {

    @Given("that the archives in the previous Scenario has been added.")
    Document added() {
        return Document();
    }

    @When("send a god-contract to remove one or more archives.")
    Document archives() {
        return Document();
    }

    @Then("wait until the network has process a number of epochs.")
    Document epochs() {
        return Document();
    }

    @Then("send a checkRead to check that the archives has been removed.")
    Document removed() {
        return Document();
    }

}

