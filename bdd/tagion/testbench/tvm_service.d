module tagion.testbench.tvm_service;

import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.tools.Environment;
import tagion.testbench.services;

import std.stdio;
import std.path;
import std.algorithm;
import std.array;
import std.range;

mixin Main!(_main);

int _main(string[] args) {
    auto tvm_service_feature = automation!(TVM);
    auto tvm_service_context = tvm_service_feature.run();
    /*
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
        */
    return 0;
}
