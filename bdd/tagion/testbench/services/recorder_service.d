module tagion.testbench.services.recorder_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.services.recorder;

enum feature = Feature(
            "Recorder chain service",
            [
        "This services should store the recorder for each epoch in chain as a file.",
        "This is an extension of the Recorder backup chain."
]);

alias FeatureContext = Tuple!(
        StoreOfTheRecorderChain, "StoreOfTheRecorderChain",
        FeatureGroup*, "result"
);

@safe @Scenario("store of the recorder chain",
        [])
class StoreOfTheRecorderChain {
    immutable(RecorderOptions) recorder_opts;

    this(immutable(RecorderOptions) recorder_opts) {
        this.recorder_opts = recorder_opts;
    }
    

    @Given("a epoch recorder with epoch number has been received")
    Document received() {
        return Document();
    }

    @When("the recorder has been store to a file")
    Document file() {
        return Document();
    }

    @Then("the file should be checked")
    Document checked() {
        return Document();
    }

}
