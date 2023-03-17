module tagion.testbench.actor_tests;

import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.tools.BDDOptions;
import tagion.testbench.tools.Environment;

import std.path : setExtension, buildPath;
import std.range : take;
import std.array;
import tagion.basic.Types : FileExtension;

import tagion.testbench.services;

mixin Main!(_main);

int _main(string[] args) {
    if (env.stage == Stage.commit) {
        BDDOptions bdd_options;
        setDefaultBDDOptions(bdd_options);
        bdd_options.scenario_name = __MODULE__;
    }

    return 0;


}
