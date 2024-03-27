module tagion.testbench.hashgraph.run_fiber_epoch;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import std.file : mkdirRecurse, rmdirRecurse, exists;
import std.path : buildPath;
import std.stdio;
import tagion.testbench.hashgraph;

enum feature = Feature(
            "Check hashgraph stability when runninng many epochs",
            []);

alias FeatureContext = Tuple!(
        RunPassiveFastHashgraph, "RunPassiveFastHashgraph",
        FeatureGroup*, "result"
);


mixin Main!(_main);
int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);

    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    writeln("WE ARE RUNNING SOMETHING");

    auto hashgraph_fiber_feature = automation!(run_fiber_epoch);
    hashgraph_fiber_feature.run;

    return 0;
}

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
