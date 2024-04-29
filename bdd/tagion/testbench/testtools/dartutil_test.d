module tagion.testbench.testtools.dartutil_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.file;
import std.path : buildPath;
import std.stdio;
import std.digest : toHexString;
import std.ascii : LetterCase;
import std.string : strip;
import std.format;

import tagion.tools.Basic;
import tagion.testbench.testtools;
import tagion.dart.Recorder;
import tagion.crypto.SecureNet;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.Document;
import tagion.behaviour.BehaviourException : check;
import tagion.testbench.testtools.helper_functions;

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    auto feature = automation!(dartutil_test);
    feature.Bullseye(module_path);
    feature.run;

    return 0;
}

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
    string dart_path;
    DART db;
    string output;

    this(string module_path) {
        this.dart_path = module_path ~ "/eye_test.drt";
    }

    @Given("initial dart file")
    Document dartFile() {
        SecureNet net = new StdSecureNet();
        net.generateKeyPair("very_secret");

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;

        HiBON hibon = new HiBON;
        hibon["a"] = 42;
        recorder.insert(Document(hibon), Archive.Type.ADD);

        DARTFile.create(dart_path, net);
        db = new DART(net, dart_path);
        db.modify(recorder);

        assert(this.dart_path.exists, "Input dart file not exists");

        return result_ok;
    }

    @When("dartutil is called with given input file")
    Document inputFile() {
        this.output = execute_tool(ToolName.dartutil, [this.dart_path, "--eye"]).strip;
        return result_ok;
    }

    @Then("the bullseye should be as expected")
    Document asExpected() {
        string expected_eye = db.fingerprint[].toHexString!(LetterCase.lower);
        string actual_eye = this.output.strip(DARTFile.eye_prefix);

        check(expected_eye == actual_eye, format("Bullseye is not as expected. Expected: {%s} Actual: {%s}", expected_eye, actual_eye));

        return result_ok;
    }
}
