module tagion.tools.tagionwave;

import std.stdio;
import core.thread;
import std.getopt;
import std.format;
import std.array : join;

import tagion.basic.Basic : Control, TrustedConcurrency;
import tagion.logger.Logger;
import tagion.services.Options;
import tagion.options.CommonOptions : setCommonOptions;

//import tagion.services.HeartBeatService;
import tagion.services.TagionService;
import tagion.services.LoggerService;
import tagion.services.TagionFactory;
import tagion.GlobalSignals;
import tagion.network.SSLOptions;
import tagion.gossip.EmulatorGossipNet;
import tagion.TaskWrapper;

mixin TrustedConcurrency;

enum main_task = "tagionwave";

void create_ssl(const(OpenSSL) openssl) {
    import std.algorithm.iteration : each;
    import std.file : exists, mkdirRecurse;
    import std.process : pipeProcess, wait, Redirect;
    import std.array : array;
    import std.path : dirName;

    if (!openssl.certificate.exists || !openssl.private_key.exists) {
        openssl.certificate.dirName.mkdirRecurse;
        openssl.private_key.dirName.mkdirRecurse;
        auto pipes = pipeProcess(openssl.command.array);
        scope (exit) {
            wait(pipes.pid);
        }
        openssl.config.each!(a => pipes.stdin.writeln(a));
        pipes.stdin.writeln(".");
        pipes.stdin.flush;
        foreach (s; pipes.stderr.byLine) {
            stderr.writeln(s);
        }
        foreach (s; pipes.stdout.byLine) {
            writeln(s);
        }
        assert(openssl.certificate.exists && openssl.private_key.exists);
    }
}


import tagion.tools.Basic;

mixin Main!(_main, "wave");

int _main(string[] args) {
    import std.file : fwrite=write;
    import std.path : setExtension;
    immutable program = args[0];
    bool version_switch;
    bool overwrite_switch;

    scope Options local_options;
    import std.getopt;

    // auto net_opts = getopt(args, std.getopt.config.passThrough, "net-mode", &(local_options.net_mode));

    setDefaultOption(local_options);

    auto config_file = "tagionwave.json";

    local_options.load(config_file);

    bool set_token = false;
    bool set_tag = false;
    void setToken(string option, string value) {
        switch(option) {
        case "server-token":
            local_options.serverFileDiscovery.token = value;
            set_token = true;
            break;
        case "server-tag":
            local_options.serverFileDiscovery.tag = value;
            set_tag = true;
            break;
        default:
            // Empty
        }
    }

    auto token_opts = getopt(args, std.getopt.config.passThrough,
            "server-token", &setToken,
        "server-tag", &setToken);

    if (set_token && set_tag) {
        local_options.save(config_file);
        writeln("Group token and tag provided.. (remove it from parameters and run the network)");
        return 0;
    }

    try {
        auto main_args = all_getopt(args, version_switch, overwrite_switch, local_options);

        if (version_switch) {
            // writefln("version %s", REVNO);
            // writefln("Git handle %s", HASH);
            return 0;
        }

        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] ", program),
                format("%s <config.json>", program),
                        ].join("\n"),
                    main_args.options);
            return 0;
        }

        if (overwrite_switch) {
            if (args.length == 2) {
                config_file = args[1];
            }
            local_options.save(config_file);
            writefln("Configure file written to %s", config_file);
            return 0;
        }

        local_options.infinity = (local_options.loops == 0);
    }
    catch (Exception e) {
        import std.stdio;

        stderr.writefln(e.msg);
        return 1;
    }

    if (args.length == 2) {
        config_file = args[1];
        local_options.load(config_file);
    }

    setOptions(local_options);

    writeln("----- Start tagion service task -----");
    immutable service_options = getOptions();
    // Set the shared common options for all services
    setCommonOptions(service_options.common);

    if (service_options.pid_file) {
        import std.process : thisProcessID;
        stderr.writefln("PID = %s written to %s", thisProcessID, options.pid_file);
        service_options.pid_file.fwrite("PID = %s\n".format(thisProcessID));
    }

    create_ssl(service_options.transaction.service.openssl);

    auto loggerService = Task!LoggerTask(service_options.logger.task_name, service_options);
    scope (exit) {
        loggerService.control(Control.STOP);
        receiveOnly!Control;
    }

    import std.stdio : stderr;

    stderr.writeln("Waiting for logger");

    const response = receiveOnly!Control;
    stderr.writeln("Logger started");
    if (response !is Control.LIVE) {
        stderr.writeln("ERROR:Logger %s", response);
    }
    log.register(main_task);

    //    Control response;
    Tid tagion_service_tid = spawn(&tagionServiceWrapper, service_options);
    scope (exit) {
        tagion_service_tid.send(Control.STOP);
        auto respond_control = receiveOnly!Control;
    }
    writeln("Wait for join");

    int result;
    receive(
            (Control response) {
        if (response is Control.END) {
            writeln("Slut!");
        }
        else {
            result = 1;
            stderr.writefln("Unexpected signal %s", response);
        }
    },
            (immutable(Exception) e) {
                stderr.writeln(e.msg);
                result = 2;
            },
            (immutable(Throwable) t) {
                stderr.writeln(t.msg);
                result = 3;
            }
        );
    return result;
}
