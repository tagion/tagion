module tagion.testbench.services.trt_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "TRT Service test",
            []);

alias FeatureContext = Tuple!(
        SendAInoiceUsingTheTRT, "SendAInoiceUsingTheTRT",
        FeatureGroup*, "result"
);

@safe @Scenario("send a inoice using the TRT",
        [])
class SendAInoiceUsingTheTRT {

    @Given("i have a running network with a trt")
    Document trt() {
        return Document();
    }

    @When("i create and send a invoice")
    Document invoice() {
        return Document();
    }

    @When("i update my wallet using the pubkey lookup")
    Document lookup() {
        return Document();
    }

    @Then("the transaction should go through")
    Document through() {
        return Document();
    }

}
