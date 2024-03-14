module tagion.testbench.e2e.run_epochs;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import tagion.testbench.e2e;

mixin Main!(_main);
int _main(string[] args) {
    auto feature = automation!(run_epochs);
    feature.run;


    return 0;

}


enum feature = Feature(
            "Check network stability when runninng many epochs",
            []);

alias FeatureContext = Tuple!(
        RunPassiveFastNetwork, "RunPassiveFastNetwork",
        FeatureGroup*, "result"
);

@safe @Scenario("Run passive fast network",
        [])
class RunPassiveFastNetwork {

    @Given("i have a running network")
    Document network() {
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
