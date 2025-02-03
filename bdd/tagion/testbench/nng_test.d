module tagion.testbench.nng_test;

import std.algorithm;
import std.array;
import std.path;
import std.range;
import std.stdio;
import tagion.behaviour.Behaviour;
import tagion.testbench.tools.Environment;
import tagion.testbench.nng;
import tagion.tools.Basic;



mixin Main!(_main);

int _main(string[] args) {
    
    nng_testsuite.testroot = buildPath(env.reporoot, "src", "lib-nngd", "nngd", "nngtests");

    auto nng_feature = automation!(nng_testsuite)();
    nng_feature.MultithreadedNNGTestSuiteWrapper();

    auto nng_context = nng_feature.run();
    return 0;

}

