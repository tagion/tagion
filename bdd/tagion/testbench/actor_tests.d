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
        auto actor_supervisor_message_feature = automation!(actor_message)();
        auto actor_supervisor_message_context = actor_supervisor_message_feature.run();
    }

    return 0;


}
