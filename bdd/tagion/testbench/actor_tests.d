module tagion.testbench.actor_tests;

import tagion.behaviour.Behaviour;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.tools.BDDOptions;
import tagion.testbench.tools.Environment;

import std.path : setExtension, buildPath;
import std.range : take;
import std.array;
import tagion.basic.Types : FileExtension;

import tagion.testbench.services;

debug = actor;

mixin Main!(_main);

int _main(string[] args) {
    if (env.stage == Stage.commit) {
        // Sending messages between supervisor & children
        version (lr282) {
            auto actor_supervisor_message_feature = automation!(actor_message)();
            auto actor_supervisor_message_context = actor_supervisor_message_feature.run();
        }

        // Supervisor with failing child
        version (lr269) {
            auto actor_supervisor_feature = automation!(actor_supervisor)();
            auto actor_supervisor_context = actor_supervisor_feature.run();
        }

        auto actor_handler_feature = automation!(actor_handler)();
        auto actor_handler_context = actor_handler_feature.run();
    }

    return 0;
}
