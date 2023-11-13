module tagion.testbench.tvm_betterc;

import std.algorithm;
import std.array;
import std.path;
import std.range;
import std.stdio;
import tagion.behaviour.Behaviour;
import tagion.testbench.tools.Environment;
import tagion.testbench.tvm;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    //    wasm_testsuite.testsuite=buildPath(__FILE__.dirName, "tvm", "testsuite");
    wasm_testsuite.testsuite = buildPath(env.reporoot, "src", "lib-wasm", "tagion", "wasm", "unitdata");

    writefln("args=%s", args);
    writefln("%s %s", __MODULE__, __FILE__);
    foreach (wast_file; args[1 .. $]) {
        auto wasm_testsuite_feature = automation!(wasm_testsuite)();
        wasm_testsuite_feature.ShouldConvertswastfileTestsuiteToWasmFileFormat(wast_file);
        wasm_testsuite_feature.ShouldLoadAwasmfileAndConvertItIntoBetterC(wasm_testsuite_feature.context[0]);
        wasm_testsuite_feature.ShouldTranspileTheWasmFileToBetterCFileAndExecutionIt(
                wasm_testsuite_feature.context[1]);
        auto wasm_testsuite_context = wasm_testsuite_feature.run();
    }
    return 0;
}
