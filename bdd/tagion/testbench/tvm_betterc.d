module tagion.testbench.tvm_betterc;

import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.tools.Environment;
import tagion.testbench.tvm;

import std.stdio;
import std.path;

mixin Main!(_main);

int _main(string[] args) {
    //    wasm_testsuite.testsuite=buildPath(__FILE__.dirName, "tvm", "testsuite");
    wasm_testsuite.testsuite = buildPath(env.reporoot, "src", "lib-wasm", "tagion", "wasm", "unitdata");

    writefln("%s %s", __MODULE__, __FILE__);
    auto wasm_testsuite_feature = automation!(wasm_testsuite)();
    wasm_testsuite_feature.ShouldConvertsWastTestsuiteToWasmFileFormat(args[1]);
    auto wasm_testsuite_context = wasm_testsuite_feature.run();

    return 0;
}
