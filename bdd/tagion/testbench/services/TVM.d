module tagion.testbench.services.TVM;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Tagion Virtual Machine services",
            [
            "This feature handles the execution of the smart contracts.",
            "The purpose of this services is to execute the contract with the input and the readonly archives received."
            ]);

alias FeatureContext = Tuple!(
        ShouldExecuteTheContract, "ShouldExecuteTheContract",
        FeatureGroup*, "result"
);

@safe @Scenario("should execute the contract.",
        [])
class ShouldExecuteTheContract {

    @Given("a contract with inputs and readonly archives.")
    Document inputsAndReadonlyArchives() {
        return Document();
    }

    @When("the format and the method of the contract has been check.")
    Document contractHasBeenCheck() {
        return Document();
    }

    @Then("the contract is execute and the result should be send to the transcript.")
    Document sendToTheTranscript() {
        return Document();
    }

    @But("if contract fails the fails should be reported to the transcript.")
    Document reportedToTheTranscript() {
        return Document();
    }

}
