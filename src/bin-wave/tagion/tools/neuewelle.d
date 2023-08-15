/// New wave implementation of the tagion node
module tagion.tools.neuewelle;

import core.sys.posix.signal;
import core.sys.posix.unistd;
import core.sync.event;
import core.thread;
import std.getopt;
import std.stdio;
import std.socket;
import std.typecons;
import std.path;
import std.concurrency;
import std.path : baseName;

import tagion.tools.Basic;
import tagion.utils.getopt;
import tagion.logger.Logger;
import tagion.basic.Version;
import tagion.tools.revision;
import tagion.actor;
import tagion.services.supervisor;
import tagion.services.options;
import tagion.GlobalSignals;

// enum EXAMPLES {
//     ver = Example("-v"),
//     db = Tuple("%s -d %s", program_name, file),
// }

// TODO: 
pragma(msg, "TODO(lr) rewrite logger with the 4th implementation of a taskwrapper");
auto startLogger() {
    import tagion.taskwrapper.TaskWrapper : Task;
    import tagion.prior_services.LoggerService;
    import tagion.basic.Types : Control;
    import tagion.prior_services.Options;
    import tagion.options.CommonOptions : setCommonOptions;

    Options options;
    setDefaultOption(options);
    auto logger_service_tid = Task!LoggerTask(options.logger.task_name, options);
    import std.stdio : stderr;

    stderr.writeln("Waiting for logger");
    const response = receiveOnly!Control;
    stderr.writeln("Logger started");
    if (response !is Control.LIVE) {
        stderr.writeln("ERROR:Logger %s", response);
        _exit(1);
    }
    return logger_service_tid;
}

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
    if(geteuid == 0) {
        stderr.writeln("FATAL: YOU SHALL NOT RUN THIS PROGRAM AS ROOT");
        return 1;
    }
    stopsignal.initialize(true, false);
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

    auto logger_service_tid = startLogger;
    scope (exit) {
        import tagion.basic.Types : Control;
        logger_service_tid.control(Control.STOP);
        receiveOnly!Control;
    }

    log.register(baseName(program));
    immutable opts = Options(
            /// InputValidatorOptions("ipc:///var/run/user/1001/neuewelle.sock")
            // InputValidatorOptions("tcp://127.0.0.1:31200")
            InputValidatorOptions(contract_sock_path)
    );
    log("Starting with options \n%s", opts.stringify);
    enum supervisor_task_name = "supervisor";
    auto supervisor_handle = spawn!Supervisor(supervisor_task_name, opts);

    if(waitforChildren(Ctrl.ALIVE)) {
        log("alive");
        stopsignal.wait;
    } else {
        log("Progam did not start");
    }

    log("Sending stop signal to supervisor");
    supervisor_handle.send(Sig.STOP);
    waitforChildren(Ctrl.END);
    log("Exiting");
    return 0;
}
