module tagion.testbench.actor_tests;

import tagion.behaviour.Behaviour;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.tools.Environment;

import std.path : setExtension, buildPath;
import std.range : take;
import std.array;
import tagion.basic.Types : FileExtension;

import tagion.testbench.actor;

debug = actor;

mixin Main!(_main);

int _main(string[] args) {
    if (env.stage == Stage.commit) {
        // See if an taskfailure sent to an actor can be will send up to the owner
        automation!taskfailure.run;

        // Request child handle and see if we can send something to it
        automation!handler.run;

        // Sending messages between supervisor & children
        automation!message.run;

        // Supervisor with failing child
        automation!supervisor.run;
    }

    return 0;
}
