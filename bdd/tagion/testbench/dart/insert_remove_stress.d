module tagion.testbench.dart.insert_remove_stress;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
        "insert random stress test",
        [
        "This test uses dartfakenet to randomly add and remove archives in the same recorder."
]);

alias FeatureContext = Tuple!(
    AddRemoveAndReadTheResult, "AddRemoveAndReadTheResult",
    FeatureGroup*, "result"
);

@safe @Scenario("add remove and read the result",
    [])
class AddRemoveAndReadTheResult {

    @Given("i have a dartfile")
    Document dartfile() {
        return Document();
    }

    @Given("i have an array of randomarchives")
    Document randomarchives() {
        return Document();
    }

    @When("i select n amount of elements in the randomarchives and add them to the dart and flip their bool. And count the number of instructions.")
    Document instructions() {
        return Document();
    }

    @Then("i read all the elements.")
    Document elements() {
        return Document();
    }

}
