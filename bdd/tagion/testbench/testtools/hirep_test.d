module tagion.testbench.testtools.hirep_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.file;
import std.path : buildPath;
import std.process;
import std.stdio;

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

    auto feature = automation!(hirep_test);
    feature.ListFiltering(module_path);
    feature.run;

    return 0;
}

enum feature = Feature(
        "hirep scenarios",
        []);

alias FeatureContext = Tuple!(
    ListFiltering, "ListFiltering",
    FeatureGroup*, "result"
);

@safe @Scenario("List filtering",
    [])
class ListFiltering {
    string input_path;
    string output_path;
    string expected_path;

    this(string module_path) {
        this.input_path = module_path ~ "/list_test.hibon";
        this.output_path = module_path ~ "/list_test_out.hibon";
        this.expected_path = module_path ~ "/list_test_exp.hibon";
    }

    @Given("initial hibon file with several records")
    Document records() {
        auto hibon1 = new HiBON;
        hibon1["a"] = 42;
        auto hibon2 = new HiBON;
        hibon2["b"] = 84;
        auto hibon3 = new HiBON;
        hibon3["c"] = 126;

        std.file.write(this.input_path, Document(hibon1)
                .serialize ~ Document(hibon2)
                .serialize ~ Document(hibon3).serialize);

        std.file.write(this.expected_path, Document(hibon2)
                .serialize ~ Document(hibon3).serialize);

        assert(this.input_path.exists, "Input hibon file not exists");

        return result_ok;
    }

    @When("hirep filter specific items in list")
    Document list() {
        // Command: cat input | hirep --list 1,2 > output
        string command = "cat " ~ this.input_path ~ " | " ~ tagionTool ~ " " ~ ToolName.hirep ~ " --list 1,2 > " ~ this
            .output_path;

        execute_pipe_shell(command);
        return result_ok;
    }

    @Then("the output of hirep should be as expected")
    Document expected() {
        check(compare_files(this.output_path, this.expected_path), "Actual output file doesn't match the expected");
        return result_ok;
    }

}
