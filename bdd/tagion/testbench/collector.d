module tagion.testbench.collector;

import tagion.behaviour.Behaviour;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.tools.BDDOptions;
import tagion.testbench.tools.Environment;

import tagion.testbench.services;

mixin Main!(_main);

int _main(string[] args) {
    if (env.stage == Stage.commit) {
        automation!collector.run;
    }

    return 0;
}
