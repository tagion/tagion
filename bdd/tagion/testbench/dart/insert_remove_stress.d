module tagion.testbench.dart.insert_remove_stress;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.file : mkdirRecurse;
import std.stdio;
import std.format;


// dart
import tagion.dart.DARTFakeNet;
import tagion.testbench.dart.dartinfo;

import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.dart.DART : DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : Archive, RecordFactory;

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

    DartInfo info;
    DART db1;

    this(DartInfo info) {
        this.info = info;
    }

    @Given("i have a dartfile")
    Document dartfile() {
        mkdirRecurse(info.module_path);
        // create the dartfile
        DART.create(info.dartfilename);

        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));
        return result_ok;
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
