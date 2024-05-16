module tagion.testbench.testtools.hibonutil_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.string : strip;
import std.format;
import std.digest : toHexString;
import std.ascii : LetterCase;
import std.file;
import std.path : buildPath;

import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.tools.Basic;
import tagion.testbench.testtools;
import tagion.behaviour.BehaviourException : check;
import tagion.testbench.testtools.helper_functions;

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    auto feature = automation!(hibonutil_test);
    feature.FormatHex(module_path);
    feature.run;

    return 0;
}

enum feature = Feature(
        "hibonutil scenarios",
        []);

alias FeatureContext = Tuple!(
    FormatHex, "FormatHex",
    FeatureGroup*, "result"
);

@safe @Scenario("FormatHex",
    [])
class FormatHex {
    string input_path;
    string output;

    this(string module_path) {
        this.input_path = buildPath(module_path, "hex_test.hibon");
    }

    @Given("input hibon file")
    Document file() {
        auto hibon = new HiBON;
        hibon["a"] = 42;
        hibon["b"] = 84;
        hibon["c"] = 126;

        writeHiBONs(this.input_path, [hibon]);
        return result_ok;
    }

    @When("hibonutil is called with given input file in format hex")
    Document hex() {
        this.output = executeTool(ToolName.hibonutil, [
                this.input_path, "-xc"
            ]).strip;
        return result_ok;
    }

    @Then("the output should be as expected")
    Document expected() @trusted {
        ubyte[] data = cast(ubyte[]) std.file.read(this.input_path);
        string expected_hex = data.toHexString!(LetterCase.lower);

        check(expected_hex == this.output, format("Output is not as expected. Expected: {%s} Actual: {%s}", expected_hex, this
                .output));

        return result_ok;
    }

}
