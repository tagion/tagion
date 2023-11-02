/// New wave implementation of the tagion node
module tagion.tools.neuewelle;

import core.stdc.stdlib : exit;
import core.sys.posix.signal;
import core.sys.posix.unistd;
import core.sync.event;
import core.thread;
import core.time;
import std.getopt;
import std.stdio;
import std.socket;
import std.typecons;
import std.path;
import std.concurrency;
import std.path : baseName, dirName;
import std.file : exists, chdir;
import std.algorithm : countUntil, map;
import std.range : iota;
import std.array;
import std.format;

import tagion.tools.Basic;
import tagion.utils.getopt;
import tagion.logger.Logger;
import tagion.basic.Version;
import tagion.tools.revision;
import tagion.actor;
import tagion.services.supervisor;
import tagion.services.options;
import tagion.services.subscription;
import tagion.services.locator;
import tagion.GlobalSignals : stopsignal;
import tagion.utils.JSONCommon;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.gossip.AddressBook : addressbook, NodeAddress;
import tagion.basic.Types : hasExtension, FileExtension;
import tagion.hibon.Document;

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
        throw new Exception("Could not start the logger");
    }
    return logger_service_tid;
}

static abort = false;
extern (C)
void signal_handler(int _) nothrow {
    try {
        if (abort) {
            printf("Terminating\n");
            exit(1);
        }
        stopsignal.set;
        abort = true;
        printf("Received stop signal, telling services to stop\n");
    }
    catch (Exception e) {
        assert(0, format("DID NOT CLOSE PROPERLY \n %s", e));
    }
}

mixin Main!(_main, "tagionwave");

int _main(string[] args) {
    immutable program = args[0];
    if (geteuid == 0) {
        stderr.writeln("FATAL: YOU SHALL NOT RUN THIS PROGRAM AS ROOT");
        return 1;
    }
    stopsignal.initialize(true, false);

    { // Handle sigint
        sigaction_t sa;
        sa.sa_handler = &signal_handler;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = 0;
        // Register the signal handler for SIGINT
        sigaction(SIGINT, &sa, null);
    }

    bool version_switch;
    bool override_switch;
    bool monitor;
    string mode0_node_opts_path;

    auto main_args = getopt(args,
            "v|version", "Print revision information", &version_switch,
            "O|override", "Override the config file", &override_switch,
            "nodeopts", "Generate single node opts files for mode0", &mode0_node_opts_path,
            "m|monitor", "Enable the monitor", &monitor,
    );

    if (main_args.helpWanted) {
        tagionGetoptPrinter(
                "Help information for tagion wave program\n" ~
                format("Usage: %s <tagionwave.json>\n", program),
                main_args.options
        );
        return 0;
    }

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    string config_file = "tagionwave.json";
    if (args.length >= 2 && args[1].hasExtension(".json")) {
        config_file = args[1];
    }

    if (override_switch) {
        Options.defaultOptions.save(config_file);
        writefln("Config file written to %s", config_file);
        return 0;
    }

    Options local_options;
    if (config_file.exists) {
        try {
            local_options.load(config_file);
            log("Running with config file %s", config_file);
        }
        catch (Exception e) {
            stderr.writefln("Error loading config file %s, %s", config_file, e.msg);
            return 1;
        }
    }
    else {
        local_options = Options.defaultOptions;
        stderr.writefln("No config file exits, running with default options");
    }
    chdir(config_file.dirName);

    // Spawn logger service
    auto logger_service_tid = startLogger;
    scope (exit) {
        import tagion.basic.Types : Control;

        logger_service_tid.control(Control.STOP);
        bool received = receiveTimeout(100.msecs, 
            (Control c) {}
        );
        if( !received ) {
            stderr.writeln("Logger did not stop properly");
        }
    }

    SubscriptionServiceHandle sub_handle;
    { // Spawn logger subscription service
        immutable subopts = Options(local_options).subscription;
        sub_handle = spawn!SubscriptionService("logger_sub", subopts);
        waitforChildren(Ctrl.ALIVE);
        log.registerSubscriptionTask("logger_sub");
    }

    log.register(baseName(program));

    locator_options = new immutable(LocatorOptions)(5, 5);
    SupervisorHandle[] supervisor_handles;

    if (local_options.wave.network_mode == NetworkMode.INTERNAL) {
        auto node_options = get_mode_0_options(local_options, monitor);


        import tagion.dart.DART;
        import tagion.dart.DARTBasic;
        import CRUD = tagion.dart.DARTcrud;
        import tagion.crypto.Types : Fingerprint;
        import std.algorithm : all;
        import tagion.communication.HiRPC;
        import tagion.script.standardnames;
        import tagion.script.common : TagionHead, GenesisEpoch, Epoch;
        import std.file : copy;
        import std.stdio : File;
        import tagion.hibon.HiBONRecord : isRecord;

        auto __net = new StdSecureNet();
        __net.generateKeyPair("wowo");

        // extra check for mode0
        Fingerprint[] bullseyes;
        foreach(node_opt; node_options) {
            DART db = new DART(__net, node_opt.dart.dart_path);
            auto b = Fingerprint(db.bullseye);
            bullseyes ~= b;

            // check that all bullseyes are the same before boot
            assert(bullseyes.all!(b => b == bullseyes[0]), "DATABASES must be booted with same bullseye - Abort");
            db.close();

            // node_opt.dart.dart_path.copy("BOOT"~node_opt.dart.dart_path);

        }

        
        // we only need to read one head since all bullseyes are the same:
        DART db = new DART(__net, node_options[0].dart.dart_path);        

        // read the databases TAGIONHEAD
        DARTIndex tagion_index = __net.dartKey(StdNames.name, TagionDomain); 
        auto hirpc = HiRPC(__net);
        const sender = CRUD.dartRead([tagion_index], hirpc);
        const receiver = hirpc.receive(sender);
        auto response = db(receiver, false);
        auto recorder = db.recorder(response.result);
        
        Document doc;
        if (!recorder.empty) {
            const head = TagionHead(recorder[].front.filed);
            writefln("Found head: %s", head.toPretty);
            DARTIndex epoch_index = __net.dartKey(StdNames.epoch, head.current_epoch);

            const _sender = CRUD.dartRead([epoch_index], hirpc);
            const _receiver = hirpc.receive(_sender);
            auto epoch_response = db(_receiver, false);
            auto epoch_recorder = db.recorder(epoch_response.result);
            doc = epoch_recorder[].front.filed;
            writefln("Epoch_found: %s", doc.toPretty);
        }

        db.close;
        network_mode0(node_options, supervisor_handles, doc);

        if (mode0_node_opts_path) {
            foreach (i, opt; node_options) {
                opt.save(buildPath(mode0_node_opts_path, format(opt.wave.prefix_format ~ "opts", i).setExtension(FileExtension
                        .json)));
            }
        }
    }
    else {
        assert(0, "NetworkMode not supported");
    }

    if (waitforChildren(Ctrl.ALIVE, 10.seconds)) {
        log("alive");
        stopsignal.wait;
    }
    else {
        log("Program did not start");
        return 1;
    }

    sub_handle.send(Sig.STOP);
    log("Sending stop signal to supervisor");
    foreach (supervisor; supervisor_handles) {
        supervisor.send(Sig.STOP);
    }
    // supervisor_handle.send(Sig.STOP);
    if (!waitforChildren(Ctrl.END, 5.seconds)) {
        log("Timed out before all services stopped");
        return 1;
    }
    log("Bye bye! ^.^");
    return 0;
}




int network_mode0(const(Options)[] node_options, ref ActorHandle!Supervisor[] supervisor_handles, Document epoch_head = Document.init) {

    import tagion.crypto.Types;
    import tagion.hibon.HiBONRecord;
    import tagion.script.common : GenesisEpoch, Epoch;
    import std.range : zip;


    struct Node {
        immutable(Options) opts;
        shared(StdSecureNet) net;
        Pubkey pkey;
    }

    Node[] nodes;

    foreach (i, opts; node_options) {
        auto net = new StdSecureNet();
        net.generateKeyPair(opts.task_names.supervisor);

        scope(exit) {
            net = null;
        }
    
        shared shared_net = (()@trusted => cast(shared) net)();
    
        nodes ~= Node(opts, shared_net, net.pubkey);
    }

    import tagion.hibon.HiBONtoText;
    if (epoch_head is Document.init) {
        foreach(n; zip(nodes, node_options)) {
            addressbook[n[0].pkey] = NodeAddress(n[1].task_names.epoch_creator);
        }
    } 
    else {
        Pubkey[] keys;
        if (epoch_head.isRecord!Epoch) {
            keys = Epoch(epoch_head).active;
        } else {
            auto genesis = GenesisEpoch(epoch_head);
            
            keys = genesis.nodes;
        }

        foreach(node_info; zip(keys, node_options)) {
            addressbook[node_info[0]] = NodeAddress(node_info[1].task_names.epoch_creator);
        }
    }

    /// spawn the nodes
    foreach (n; nodes) {
        supervisor_handles ~= spawn!Supervisor(n.opts.task_names.supervisor, n.opts, n.net);
    }

    return 0;
}

const(Options)[] get_mode_0_options(const(Options) options, bool monitor = false) {
    const number_of_nodes = options.wave.number_of_nodes;
    const prefix_f = options.wave.prefix_format;
    Options[] all_opts;
    foreach (node_n; 0 .. number_of_nodes) {
        auto opt = Options(options);
        opt.setPrefix(format(prefix_f, node_n));
        opt.epoch_creator.timeout = 100;
        all_opts ~= opt;
    }

    if (monitor) {
        all_opts[0].monitor.enable = true;
    }

    return all_opts;
}
