module tagion.testbench.testtools.dartutil;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
        "dartutil scenarios",
        []);

alias FeatureContext = Tuple!(
    Bullseye, "Bullseye",
    FeatureGroup*, "result"
);

@safe @Scenario("Bullseye",
    [])
class Bullseye {

    @Given("initial dart file")
    Document dartFile() {
        return Document();
    }

    @When("dartutil is called with given input file")
    Document inputFile() {
        return Document();
    }

    @Then("the bullseye should be as expected")
    Document asExpected() {
        return Document();
    }

}
