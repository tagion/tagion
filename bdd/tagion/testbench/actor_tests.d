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
        // See if an taskfailure sent to an actor can be will send up to the owner
        auto actor_taskfailure_feature = automation!(actor_taskfailure)();
        auto actor_taskfailure_context = actor_taskfailure_feature.run();

        // Request child handle and see if we can send something to it
        auto actor_handle_feature = automation!(actor_handler)();
        auto actor_handle_context = actor_taskfailure_feature.run();

        // Sending messages between supervisor & children
        auto actor_supervisor_message_feature = automation!(actor_message)();
        auto actor_supervisor_message_context = actor_supervisor_message_feature.run();

        // Supervisor with failing child
        auto actor_supervisor_feature = automation!(actor_supervisor)();
        auto actor_supervisor_context = actor_supervisor_feature.run();
    }

    return 0;
}
