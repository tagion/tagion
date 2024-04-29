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

    feature.NoFilters(buildPath(module_path, "NoFilters"));
    feature.NoFiltersWithNot(buildPath(module_path, "NoFiltersWithNot"));
    feature.ListFiltering(buildPath(module_path, "ListFiltering"));
    feature.ListFilteringMixed(buildPath(module_path, "ListFilteringMixed"));
    feature.TestOutputAndStdout(buildPath(module_path, "TestOutputAndStdout"));
    feature.TestName(buildPath(module_path, "TestName"));
    feature.TestRecordtype(buildPath(module_path, "TestRecordtype"));
    feature.TestType(buildPath(module_path, "TestType"));
    feature.TestNameAndType(buildPath(module_path, "TestNameAndType"));
    feature.TestRecursive(buildPath(module_path, "TestRecursive"));
    feature.TestRecursiveWithNot(buildPath(module_path, "TestRecursiveWithNot"));
    feature.TestSubhibon(buildPath(module_path, "TestSubhibon"));
    feature.TestSubhibonWithNot(buildPath(module_path, "TestSubhibonWithNot"));
    feature.run;

    return 0;
}

enum feature = Feature(
        "hirep scenarios",
        []);

alias FeatureContext = Tuple!(
    NoFilters, "NoFilters",
    NoFiltersWithNot, "NoFiltersWithNot",
    ListFiltering, "ListFiltering",
    ListFilteringMixed, "ListFilteringMixed",
    TestOutputAndStdout, "TestOutputAndStdout",
    TestName, "TestName",
    TestRecordtype, "TestRecordtype",
    TestType, "TestType",
    TestNameAndType, "TestNameAndType",
    TestRecursive, "TestRecursive",
    TestRecursiveWithNot, "TestRecursiveWithNot",
    TestSubhibon, "TestSubhibon",
    TestSubhibonWithNot, "TestSubhibonWithNot",
    FeatureGroup*, "result"
);

@safe @Scenario("No filters",
    [])
class NoFilters {

    this(string module_path) {
    }

    @Given("initial hibon file with several records")
    Document records() {
        return Document();
    }

    @When("hirep run without filters")
    Document filters() {
        return Document();
    }

    @Then("the output should be as initial hibon")
    Document hibon() {
        return Document();
    }

}

@safe @Scenario("No filters with not",
    [])
class NoFiltersWithNot {

    this(string module_path) {
    }

    @Given("initial hibon file with several records")
    Document records() {
        return Document();
    }

    @When("hirep run without filters with not")
    Document not() {
        return Document();
    }

    @Then("the output should be empty")
    Document empty() {
        return Document();
    }

}

@safe @Scenario("List filtering",
    [])
class ListFiltering {
    string input_path;
    string expected_path;

    string output_items_path;
    string output_range_path;

    this(string module_path) {
        mkdirRecurse(module_path);

        this.input_path = buildPath(module_path, "in.hibon");
        this.expected_path = buildPath(module_path, "exp.hibon");
        this.output_items_path = buildPath(module_path, "out_items.hibon");
        this.output_range_path = buildPath(module_path, "out_range.hibon");
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
        assert(this.expected_path.exists, "Expected hibon file not exists");

        return result_ok;
    }

    @When("hirep filter several specific items in list")
    Document itemsInList() {
        string command = tagionTool ~ " " ~ ToolName.hirep ~ " --list 1,2";
        execute_spawn_shell(command, this.input_path, this.output_items_path);

        return result_ok;
    }

    @When("hirep filter the same with range in list")
    Document rangeInList() {
        string command = tagionTool ~ " " ~ ToolName.hirep ~ " --list 1..3";
        execute_spawn_shell(command, this.input_path, this.output_range_path);

        return result_ok;
    }

    @Then("both outputs should be the same and as expected")
    Document andAsExpected() {
        check(compare_files(this.output_items_path, this.expected_path), "Actual output doesn't match the expected");
        check(compare_files(this.output_items_path, this.output_range_path), "Items filtering doesn't match range filtering");
        return result_ok;
    }
}

@safe @Scenario("List filtering mixed",
    [])
class ListFilteringMixed {

    this(string module_path) {
    }

    @Given("initial hibon file with several records")
    Document records() {
        return Document();
    }

    @When("hirep filter items in list mixed with name specified")
    Document specified() {
        return Document();
    }

    @Then("filtered records should match both filters")
    Document filters() {
        return Document();
    }

}

@safe @Scenario("Test output and stdout",
    [])
class TestOutputAndStdout {

    this(string module_path) {
    }

    @Given("initial hibon file with several records")
    Document severalRecords() {
        return Document();
    }

    @When("hirep run with output specified")
    Document outputSpecified() {
        return Document();
    }

    @When("hirep run with stdout")
    Document withStdout() {
        return Document();
    }

    @Then("the output file should be equal to stdout")
    Document toStdout() {
        return Document();
    }

}

@safe @Scenario("Test name",
    [])
class TestName {

    this(string module_path) {
    }

    @Given("initial hibon file with several records with name")
    Document withName() {
        return Document();
    }

    @When("hirep run with name specified")
    Document nameSpecified() {
        return Document();
    }

    @Then("the output should contain only records with given name")
    Document givenName() {
        return Document();
    }

}

@safe @Scenario("Test recordtype",
    [])
class TestRecordtype {

    this(string module_path) {
    }

    @Given("initial hibon file with several records with recordtype")
    Document withRecordtype() {
        return Document();
    }

    @When("hirep run with recordtype specified")
    Document recordtypeSpecified() {
        return Document();
    }

    @Then("the output should contain only records with given recordtype")
    Document givenRecordtype() {
        return Document();
    }

}

@safe @Scenario("Test type",
    [])
class TestType {

    this(string module_path) {
    }

    @Given("initial hibon file with several records with type")
    Document withType() {
        return Document();
    }

    @When("hirep run with type specified")
    Document typeSpecified() {
        return Document();
    }

    @Then("the output should contain only records with given type")
    Document givenType() {
        return Document();
    }

}

@safe @Scenario("Test name and type",
    [])
class TestNameAndType {

    this(string module_path) {
    }

    @Given("initial hibon file with several records with name and type")
    Document type() {
        return Document();
    }

    @When("hirep run with name and type specified")
    Document specified() {
        return Document();
    }

    @Then("filtered records should match both filters")
    Document filters() {
        return Document();
    }

}

@safe @Scenario("Test recursive",
    [])
class TestRecursive {

    this(string module_path) {
    }

    @Given("initial hibon file with records with subhibon")
    Document subhibon() {
        return Document();
    }

    @When("hirep run with args specified")
    Document specified() {
        return Document();
    }

    @Then("the output should contain both records with match in top level and nested levels")
    Document levels() {
        return Document();
    }

}

@safe @Scenario("Test recursive with not",
    [])
class TestRecursiveWithNot {

    this(string module_path) {
    }

    @Given("initial hibon file with records with subhibon")
    Document subhibon() {
        return Document();
    }

    @When("hirep run with args specified")
    Document specified() {
        return Document();
    }

    @Then("the output should filter out both records with match in top level and nested levels")
    Document levels() {
        return Document();
    }

}

@safe @Scenario("Test subhibon",
    [])
class TestSubhibon {

    this(string module_path) {
    }

    @Given("initial hibon file with records with subhibon")
    Document subhibon() {
        return Document();
    }

    @When("hirep run with args specified")
    Document specified() {
        return Document();
    }

    @Then("the output should contain only subhibon that matches filter")
    Document filter() {
        return Document();
    }

}

@safe @Scenario("Test subhibon with not",
    [])
class TestSubhibonWithNot {

    this(string module_path) {
    }

    @Given("hirep tool")
    Document tool() {
        return Document();
    }

    @When("hirep run with subhibon and not flag")
    Document flag() {
        return Document();
    }

    @Then("hirep should fail with error message")
    Document message() {
        return Document();
    }

}
