module tagion.testbench.tvm.betterc_tvm;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Test of the wasm to betterc execution",
            [
            "This feature test of transpiler from wasm to betterC parses of the testsuite.",
            "Specified in [WebAssembly testsuite](https://github.com/WebAssembly/testsuite)"
            ]);

alias FeatureContext = Tuple!(
        ShouldConvertsWastTestsuiteToWasmFileFormat, "ShouldConvertsWastTestsuiteToWasmFileFormat",
        ShouldLoadAWasmFileAndConvertItIntoBetterC, "ShouldLoadAWasmFileAndConvertItIntoBetterC",
        ShouldCompileAndTheBetterCFileAndExecutionIn, "ShouldCompileAndTheBetterCFileAndExecutionIn",
        FeatureGroup*, "result"
);

@safe @Scenario("should converts wast testsuite to wasm file format",
        [])
class ShouldConvertsWastTestsuiteToWasmFileFormat {

    @Given("a wast testsuite file")
    Document file() {
        return Document();
    }

    @When("the wast file has successfully been converted to WebAssembly")
    Document webAssembly() {
        return Document();
    }

    @Then("write the wasm-binary data of to a #wasm-file")
    Document wasmfile() {
        return Document();
    }

}

@safe @Scenario("should load a wasm file and convert it into betterC",
        [])
class ShouldLoadAWasmFileAndConvertItIntoBetterC {

    @Given("the testsuite file in #wasm-file format")
    Document wasmfileFormat() {
        return Document();
    }

    @Then("convert the #wasm-file into betteC #dlang-file format")
    Document dlangfileFormat() {
        return Document();
    }

}

@safe @Scenario("should compile and the betterC file and execution in.",
        [])
class ShouldCompileAndTheBetterCFileAndExecutionIn {

    @Given("the testsuite #dlang-file in betterC/D format.")
    Document format() {
        return Document();
    }

    @When("the #dlang-file has been compile in unittest mode.")
    Document mode() {
        return Document();
    }

    @Then("execute the unittest file and check that all unittests parses.")
    Document parses() {
        return Document();
    }

}
