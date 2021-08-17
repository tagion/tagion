module tagion.node;

import tagion.crypto.SecureNet: StdSecureNet;

import p2plib = p2p.node;

//import p2p.connection;
import p2p.callback;
import p2p.cgo.helper;

import std.stdio;
import core.thread;
import std.getopt;
import std.format;
import std.concurrency;
import std.array: join;

import tagion.basic.Basic: Control;
import tagion.Options;
import tagion.gossip.EmulatorGossipNet;
import tagion.services.HeartBeatService;
import tagion.services.P2pTagionService;
import tagion.services.LoggerService;
import tagion.basic.Logger;
import tagion.GlobalSignals;
import tagion.Keywords: NetworkMode, ValidNetwrokModes;
import tagion.services.TagionFactory;

import tagion.services.FileDiscoveryService;

pragma(msg, "Fixme(cbr): Rename the tagion Node to Prime");
// import tagion.revision;

enum MainTask = "tagion_wave";

int main(string[] args) {
    immutable inner_task_name = "internal";

    immutable program = args[0];
    bool version_switch;
    bool over_write_switch;

    scope Options local_options;
    import std.getopt;

    auto net_opts = getopt(args, std.getopt.config.passThrough, "net-mode", &(
            local_options.net_mode));

    Options opts;
    setOptions(opts);
    opts.ip = "127.0.0.1";
    shared(p2plib.Node) p2pnode;

    StdSecureNet net = new StdSecureNet;

    setDefaultOption(local_options);

    auto config_file = "tagion_wave.json";

    local_options.load(config_file);

    bool set_token = false;
    bool set_tag = false;
    void setToken(string option, string value) {
        if (option == "server-token") {
            local_options.serverFileDiscovery.token = value;
            set_token = true;
        }
        if (option == "server-tag") {
            local_options.serverFileDiscovery.tag = value;
            set_tag = true;
        }
    }

    auto token_opts = getopt(args, std.getopt.config.passThrough,
            "server-token", format("Token to access shared server"), &setToken,
            "server-tag", format("Group tag(should be the same as in token payload)"), &setToken);
    if (set_token && set_tag) {
        local_options.save(config_file);
        writeln("Group token and tag provided.. (remove it from parameters and run the network)");
        return 0;
    }

    try {
        auto main_args = all_getopt(args, version_switch, over_write_switch, local_options);

        if (version_switch) {
            writefln("version %s", REVNO);
            writefln("Git handle %s", HASH);
            return 0;
        }

        if (main_args.helpWanted || net_opts.helpWanted) {
            defaultGetoptPrinter(
                    [
                    format("%s version %s", program, REVNO),
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...] ", program),
                    format("%s <config.json>", program),
                    ].join("\n"),//                "This program run a hashwave tagion test net.",
                    main_args.options);
            return 0;
        }

        //        local_options=getOptions();
        if (over_write_switch) {

            local_options.save(config_file);
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

    auto logger_tid = spawn(&loggerTask, service_options);

    scope (exit) {
        logger_tid.send(Control.STOP);
        auto respond_control = receiveOnly!Control;
    }

    import std.stdio: stderr;

    stderr.writeln("Waiting for logger");

    const response = receiveOnly!Control;
    stderr.writeln("Logger started");
    if (response !is Control.LIVE) {
        stderr.writeln("ERROR:Logger %s", response);
    }
    log.register(MainTask);

    //    Control response;
    // Tid tagion_service_tid = spawn(&tagionServiceWrapper, service_options);
    Options opts_;
    opts_.ip = "127.0.0.1";
    p2pnode = initialize_node(opts_);

    Tid tagion_service_tid = spawn(&fileDiscoveryService, net.pubkey, p2pnode.LlistenAddress, opts.discovery.task_name, cast(
            immutable) opts_);

    // scope(exit){
    //     tagion_service_tid.send(Control.STOP);
    //     auto respond_control = receiveOnly!Control;
    // }
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
            (immutable(Exception) e) { const print_e = e; result = 2; },
            (immutable(Throwable) t) { const print_t = t; result = 3; });
    return result;
}
