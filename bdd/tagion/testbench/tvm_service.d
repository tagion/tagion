module tagion.testbench.tvm_service;

import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.tools.Environment;
import tagion.testbench.services;
import tagion.services.TVM;
import tagion.services.options;
import tagion.actor.actor;
import std.stdio;
import std.path;
import std.algorithm;
import std.array;
import std.range;
import core.thread;
import core.time;

mixin Main!(_main);

int _main(string[] args) {
    Options local_opts;
    local_opts.defaultOptions;
    immutable opts = Options(local_opts);
    auto handle = spawn(immutable(TVMService)(opts.tvm, opts.task_names), opts.task_names.tvm);

    waitforChildren(Ctrl.STARTING);
    scope (exit) {
        waitforChildren(Ctrl.END);
    }

    auto tvm_service_feature = automation!(TVM);
    auto tvm_service_context = tvm_service_feature.run();
    //Thread.sleep(2.seconds);
    handle.send(Sig.STOP);
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
