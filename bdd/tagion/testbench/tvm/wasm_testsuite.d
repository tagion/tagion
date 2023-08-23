module tagion.testbench.tvm.wasm_testsuite;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.stdio;
import tagion.testbench.tools.Environment;
import std.file : fread = read, fwrite = write, readText, exists;
import std.path;
import std.process;
import std.format;
import std.array;
import tagion.wasm.WastTokenizer;
import tagion.wasm.WasmWriter;
import tagion.wasm.WasmReader;
import tagion.wasm.WastParser;
import tagion.wasm.WasmBetterC;
import tagion.behaviour : check;
import tagion.basic.Types : FileExtension;

enum feature = Feature(
            "Test of the wasm to betterc execution",
            [
            "This feature test of transpiler from wasm to betterC parses of the testsuite.",
            "Specified in [WebAssembly testsuite](https://github.com/WebAssembly/testsuite)"
            ]);

alias FeatureContext = Tuple!(
        ShouldConvertswastfileTestsuiteToWasmFileFormat, "ShouldConvertswastfileTestsuiteToWasmFileFormat",
        ShouldLoadAwasmfileAndConvertItIntoBetterC, "ShouldLoadAwasmfileAndConvertItIntoBetterC",
        ShouldTranspileTheWasmFileToBetterCFileAndExecutionIt, "ShouldTranspileTheWasmFileToBetterCFileAndExecutionIt",
        FeatureGroup*, "result"
);

static string testsuite;
@safe @Scenario("should converts #wast-file testsuite to wasm file format",
        [])
class ShouldConvertswastfileTestsuiteToWasmFileFormat {

    string wast_file;
    string wasm_file;
    WastTokenizer tokenizer;
    WasmWriter writer;
    this(const string wast_file) {
        this.wast_file = buildPath(testsuite, wast_file);
        wasm_file = buildPath(env.bdd_results, wast_file.baseName.setExtension("wasm"));
    }

    @Given("a wast testsuite file")
    Document file() {
        writefln("%s", __FUNCTION__);
        immutable wast_text = wast_file.readText;
        tokenizer = WastTokenizer(wast_text);
        return result_ok;
    }

    @When("the wast file has successfully been converted to WebAssembly")
    Document webAssembly() {
        writer = new WasmWriter;
        auto wast_parser = WastParser(writer);
        wast_parser.parse(tokenizer);
        return result_ok;
    }

    @Then("write the wasm-binary data of to a #wasm-file")
    Document wasmfile() {
        wasm_file = buildPath(env.bdd_results, wast_file.baseName.setExtension("wasm"));
        writefln("wasm file %s", wasm_file);
        wasm_file.fwrite(writer.serialize);
        return result_ok;
    }

}

@safe @Scenario("should load a #wasm-file and convert it into betterC",
        [])
class ShouldLoadAwasmfileAndConvertItIntoBetterC {
    string wasm_file;
    string betterc_file;
    WasmReader reader;
    this(ShouldConvertswastfileTestsuiteToWasmFileFormat load_wasm) {
        wasm_file = load_wasm.wasm_file;
        betterc_file = wasm_file.setExtension("d");
    }

    @Given("the testsuite file in #wasm-file format")
    Document wasmfileFormat() @trusted {
        writefln("%s", __FUNCTION__);
        immutable data = cast(immutable(ubyte)[]) wasm_file.fread;
        reader = WasmReader(data);
        return result_ok;
    }

    @Then("convert the #wasm-file into betteC #dlang-file format")
    Document dlangfileFormat() {
        writefln("betterc_file=%s", betterc_file);
        auto fout = File(betterc_file, "w");
        scope (exit) {
            fout.close;
        }
        auto src_out = wasmBetterC(reader, fout);
        src_out.module_name = betterc_file.baseName(FileExtension.dsrc);
        src_out.imports = environment.get("imports", null).split.array;
        src_out.attributes = environment.get("attributes", null).split.array;
        src_out.serialize;
        return result_ok;
    }

}

@safe @Scenario("should transpile the wasm file to betterC file and execution it.",
        [])
class ShouldTranspileTheWasmFileToBetterCFileAndExecutionIt {
    string betterc_file;
    string test_file;
    this(ShouldLoadAwasmfileAndConvertItIntoBetterC transpiled) {
        betterc_file = transpiled.betterc_file;
        test_file = betterc_file.stripExtension;
    }

    @Given("the testsuite #dlang-file in betterC/D format.")
    Document betterc_format() {
        check(betterc_file.exists, format("%s not found", betterc_file));
        return result_ok;
    }

    @When("the #dlang-file has been compile in unittest mode.")
    Document compile() {
        auto cmd = environment["DCOMPILE"];

        cmd = [cmd, betterc_file, format("-of=%s", test_file)].join(" ");
        auto pid = spawnShell(cmd);
        writefln("%s", cmd);
        const ret = wait(pid);
        check(ret == 0, format("Compilation of %s faild", betterc_file));
        return result_ok;
    }

    @Then("execute the unittest file and check that all unittests parses.")
    Document run_test() @trusted {
        writefln("test_file %s", test_file);
        auto pid = spawnShell(test_file);
        const ret = wait(pid);
        check(ret == 0, format("Test %s failed (see logfile)", test_file));
        return result_ok;
    }

}
