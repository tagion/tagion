module tagion.testbench.e2e.api;

import std.typecons;

import tagion.behaviour;
import tagion.hibon.Document;
import tagion.tools.Basic : Main;
import tagion.testbench.test_network_interface;

int _main(string[] args) {
    return -1;
}

enum feature = Feature(
            "Test that shell and kernel api are consistent",
            []);

alias FeatureContext = Tuple!(
        TestAPIResponseType, "TestAPIResponseType",
        FeatureGroup*, "result"
);

@safe @Scenario("Check individual that individual hirpc methods have the same response type",
        [])
class TestAPIResponseType {
    this(ITestNet network) {
    }

    @Given("I Have a network with a kernel and a shell")
    Document iHasNetwork() {
        return Document();
    }

    @When("I Send a dartRead")
    Document iSendDartRead() {
        return Document();
    }

    @When("I Send a dartCheckRead")
    Document iSendDartCheckRead() {
        return Document();
    }

    @Then("cleanup")
    Document cleanup() {
        return Document();
    }
}
