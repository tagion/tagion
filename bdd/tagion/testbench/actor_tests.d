module tagion.testbench.actor_tests;

import std.array;
import std.path : buildPath, setExtension;
import std.range : take;
import std.traits : moduleName;
import tagion.basic.Types : FileExtension;
import tagion.behaviour.Behaviour;
import tagion.testbench.actor;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

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
        version (none)
            automation!supervisor.run;
    }

    return 0;
}
