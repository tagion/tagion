module tagion.testbench.services.epoch_creator;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

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

    this() {
        //empty
    }

    @Given("I have 5 nodes and start them in mode0")
    Document mode0() {
        return Document();
    }

    @When("i sent a payload to node0")
    Document node0() {
        return Document();
    }

    @Then("all the nodes should create an epoch containing the payload")
    Document payload() {
        return Document();
    }

}
