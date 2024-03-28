module tagion.testbench.services.trt_contract;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
        "TRT contract scenarios",
        []);

alias FeatureContext = Tuple!(
    ProperContract, "ProperContract",
    InvalidContract, "InvalidContract",
    FeatureGroup*, "result"
);

@safe @Scenario("Proper contract",
    [])
class ProperContract {

    @Given("a network")
    Document network() {
        return result_ok;
    }

    @Given("a correctly signed contract")
    Document contract() {
        return result_ok;
    }

    @When("the contract is sent to the network and goes through")
    Document through() {
        return result_ok;
    }

    @Then("the contract should be saved in the TRT")
    Document tRT() {
        return result_ok;
    }

}

@safe @Scenario("Invalid contract",
    [])
class InvalidContract {

    @Given("a network")
    Document aNetwork() {
        return result_ok;
    }

    @Given("a incorrect contract which fails in the Transcript")
    Document theTranscript() {
        return result_ok;
    }

    @When("the contract is sent to the network")
    Document theNetwork() {
        return result_ok;
    }

    @Then("it should be rejected")
    Document beRejected() {
        return result_ok;
    }

    @Then("the contract should not be stored in the TRT")
    Document theTRT() {
        return result_ok;
    }

}
