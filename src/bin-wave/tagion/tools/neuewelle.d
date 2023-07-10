/// New wave implementation of the tagion node
module tagion.tools.neuewelle;

import core.sys.posix.signal;
import core.sync.event;
import core.thread;
import std.getopt;
import std.stdio;
import std.socket;
import std.typecons;
import std.path;
import std.concurrency;

import tagion.tools.Basic;
import tagion.utils.getopt;
import tagion.basic.Version;
import tagion.tools.revision;
import tagion.GlobalSignals : abort;
import tagion.actor;
import tagion.services.supervisor;
import tagion.GlobalSignals;

// enum EXAMPLES {
//     ver = Example("-v"),
//     db = Tuple("%s -d %s", program_name, file),
// }

extern (C)
void signal_handler(int _) @trusted nothrow {
    try {
        stopsignal.set;
        writeln("Received stop signal");
    }
    catch (Exception e) {
        assert(0, format("DID NOT CLOSE PROPERLY \n %s", e));
    }
}

mixin Main!(_main);

int _main(string[] args) {

    sigaction_t sa;
    sa.sa_handler = &signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    // Register the signal handler for SIGINT
    sigaction(SIGINT, &sa, null);

    bool version_switch;
    immutable program = args[0];

    auto main_args = getopt(args,
            "v|version", "Print revision information", &version_switch
    );

    if (main_args.helpWanted) {
        tagionGetoptPrinter(
                format("Help information for %s\n", program),
                main_args.options
        );
        return 0;
    }

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    enum supervisor_task_name = "supervisor";
    auto supervisor_handle = spawn!Supervisor(supervisor_task_name);
    waitfor([supervisor_task_name], Ctrl.ALIVE);

    writeln("alive");
    stopsignal.wait;
    writeln("Sending stop signal to supervisor");
    supervisor_handle.send(Sig.STOP);
    writeln("waiting for all threads");
    // thread_joinAll;

    writeln("Exiting");
    return 0;
}
