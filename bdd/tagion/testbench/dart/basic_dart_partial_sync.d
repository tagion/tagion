module tagion.testbench.dart.basic_dart_partial_sync;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;

enum feature = Feature(
        "DARTSynchronization partial sync.",
        ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
    PartialSync, "PartialSync",
    FeatureGroup*, "result"
);

@safe @Scenario("Partial sync.",
    [])
class PartialSync {

    @Given("I have a dartfile1 with pseudo random data.")
    Document randomData() {
        return Document();
    }

    @Given("I have added some of the pseudo random data to dartfile2.")
    Document toDartfile2() {
        return Document();
    }

    @Given("I synchronize dartfile1 with dartfile2.")
    Document withDartfile2() {
        return Document();
    }

    @Then("the bullseyes should be the same.")
    Document theSame() {
        return Document();
    }

}
