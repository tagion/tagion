module tagion.testbench.hashgraph.run_fiber_epoch;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Check hashgraph stability when runninng many epochs",
            []);

alias FeatureContext = Tuple!(
        RunPassiveFastHashgraph, "RunPassiveFastHashgraph",
        FeatureGroup*, "result"
);

@safe @Scenario("Run passive fast hashgraph",
        [])
class RunPassiveFastHashgraph {

    @Given("i have a running hashgraph")
    Document hashgraph() {
        return Document();
    }

    @When("the nodes creates epochs")
    Document epochs() {
        return Document();
    }

    @Then("the epochs should be the same")
    Document same() {
        return Document();
    }

}
