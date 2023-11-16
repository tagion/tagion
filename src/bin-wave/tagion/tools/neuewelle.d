/// New wave implementation of the tagion node
module tagion.tools.neuewelle;

import core.stdc.stdlib : exit;
import core.sync.event;
import core.sys.posix.signal;
import core.sys.posix.unistd;
import core.thread;
import core.time;
import std.algorithm : countUntil, map;
import std.array;
import std.file : chdir, exists;
import std.format;
import std.getopt;
import std.path;
import std.path : baseName, dirName;
import std.range : iota;
import std.socket;
import std.stdio;
import std.typecons;

// import tagion.utils.pretend_safe_concurrency : send;
import tagion.GlobalSignals : segment_fault, stopsignal;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types : FileExtension, hasExtension;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.gossip.AddressBook : NodeAddress, addressbook;
import tagion.hibon.Document;
import tagion.logger.Logger;
import tagion.services.locator;
import tagion.services.logger;
import tagion.services.options;
import tagion.services.subscription;
import tagion.services.supervisor;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.utils.JSONCommon;
import tagion.utils.getopt;
import tagion.tools.toolsexception;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.Term;

static abort = false;
private extern (C)
void signal_handler(int signal) nothrow {
    try {
        if (signal !is SIGINT) {
            return;
        }

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
    string bootkeys_path;
    /*
    * Boot key format expected for mode0
    * nodename0:pincode0
    * nodename1:pincode1
    * nodename2:pincode2
    * ...      : ...
    * The directory where the wallet config_file should be placed is 
    * <bootkeys_path>/<nodenameX>/wallet.json
    *
    */
    File fin=stdin; /// Console input for the bootkeys
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
        int rc = sigaction(SIGINT, &sa, null);
        assert(rc == 0, "sigaction error");
    }
    { // Handle sigv
        sigaction_t sa;
        sa.sa_sigaction = &segment_fault;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = SA_RESTART;

        int rc = sigaction(SIGSEGV, &sa, null);
        assert(rc == 0, "sigaction error");
    }

    bool version_switch;
    bool override_switch;
    bool monitor;
    debug {
        bool fail_fast = true;
    }
    else {
        bool fail_fast;
    }

    string mode0_node_opts_path;
    string[] override_options;

    auto main_args = getopt(args,
            "v|version", "Print revision information", &version_switch,
            "O|override", "Override the config file", &override_switch,
            "option", "Set an option", &override_options,
            "fail-fast", "Set the fail strategy, fail-fast=%s".format(fail_fast), &fail_fast,
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

    Options local_options;
    if (config_file.exists) {
        try {
            local_options.load(config_file);
            log("Running with config file %s", config_file);
            chdir(config_file.dirName);
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

    // Experimental!!
    if (!override_options.empty) {
        import std.json;
        import tagion.utils.JSONCommon;

        JSONValue json = local_options.toJSON;

        void set_val(JSONValue j, string[] _key, string val) {
            if (_key.length == 1) {
                j[_key[0]] = val.toJSONType(j[_key[0]].type);
                return;
            }
            set_val(j[_key[0]], _key[1 .. $], val);
        }

        foreach (option; override_options) {
            string[] key_value = option.split(":");
            assert(key_value.length == 2, format("Option '%s' invalid, missing key=value", option));
            auto value = key_value[1];
            string[] key = key_value[0].split(".");
            set_val(json, key, value);
        }
        // If options does not parse as a string then some types will not be interpreted correctly
        local_options.parseJSON(json.toString);
    }

    if (override_switch) {
        local_options.save(config_file);
        writefln("Config file written to %s", config_file);
        return 0;
    }

    scope (failure) {
        log("Bye bye :(");
    }

    // Spawn logger service
    immutable logger = LoggerService(LoggerServiceOptions(LogType.Console));
    auto logger_service = spawn(logger, "logger");
    log.set_logger_task(logger_service.task_name);
    writeln("logger started: ", waitforChildren(Ctrl.ALIVE));
    scope (exit) {
        logger_service.send(Sig.STOP);
    }

    ActorHandle sub_handle;
    { // Spawn logger subscription service
        immutable subopts = Options(local_options).subscription;
        sub_handle = spawn!SubscriptionService("logger_sub", subopts);
        writeln("logsub started: ", waitforChildren(Ctrl.ALIVE));
        log.registerSubscriptionTask("logger_sub");
    }

    log.register(baseName(program));

    locator_options = new immutable(LocatorOptions)(20, 5);
    ActorHandle[] supervisor_handles;

    if (local_options.wave.network_mode == NetworkMode.INTERNAL) {
        auto node_options = get_mode_0_options(local_options, monitor);

        import std.algorithm : all;
        import std.file : copy;
        import std.path : baseName, dirName;
        import std.stdio : File;
        import tagion.communication.HiRPC;
        import tagion.crypto.Types : Fingerprint;
        import tagion.dart.DART;
        import tagion.dart.DARTBasic;
        import CRUD = tagion.dart.DARTcrud;
        import tagion.hibon.HiBONRecord : isRecord;
        import tagion.script.common : Epoch, GenesisEpoch, TagionHead;
        import tagion.script.standardnames;

        auto __net = new StdSecureNet();
        __net.generateKeyPair("wowo");

        // extra check for mode0
        // Check bullseyes
        Fingerprint[] bullseyes;
        foreach (node_opt; node_options) {
            if (!node_opt.dart.dart_path.exists) {
                stderr.writefln("Missing dartfile %s", node_opt.dart.dart_path);
                return 1;
            }
            DART db = new DART(__net, node_opt.dart.dart_path);
            auto b = Fingerprint(db.bullseye);
            bullseyes ~= b;

            // check that all bullseyes are the same before boot
            assert(bullseyes.all!(b => b == bullseyes[0]), "DATABASES must be booted with same bullseye - Abort");
            db.close();

            const new_filename = buildPath(dirName(node_opt.dart.dart_path), format("boot-%s", baseName(
                    node_opt.dart.dart_path)));
            writefln("copying file %s to %s", db.filename, new_filename);
            node_opt.dart.dart_path.copy(new_filename);
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
        network_mode0(node_options, supervisor_handles, bootkeys_path, fin, doc);

        if (mode0_node_opts_path) {
            foreach (i, opt; node_options) {
                opt.save(buildPath(mode0_node_opts_path, format(opt.wave.prefix_format ~ "opts", i).setExtension(
                        FileExtension
                        .json)));
            }
        }
    }
    else {
        assert(0, "NetworkMode not supported");
    }

    if (waitforChildren(Ctrl.ALIVE, 30.seconds)) {
        log("alive");
        bool signaled;
        import tagion.utils.pretend_safe_concurrency : receiveTimeout;

        do {
            signaled = stopsignal.wait(100.msecs);
            if (!signaled) {
                if (fail_fast) {
                    signaled = receiveTimeout(
                            Duration.zero,
                            (TaskFailure tf) { log.fatal("Stopping because of unhandled taskfailure\n%s", tf); }
                    );
                }
                else {
                    receiveTimeout(
                            Duration.zero,
                            (TaskFailure tf) { log.error("Received an unhandled taskfailure\n%s", tf); }
                    );
                }
            }
        }
        while (!signaled);
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

int network_mode0(
        const(Options)[] node_options,
        ref ActorHandle[] supervisor_handles,
        string bootkeys_path,
        File fin,
        Document epoch_head = Document.init) {

    import std.range : zip;
    import tagion.crypto.Types;
    import tagion.hibon.HiBONRecord;
    import tagion.script.common : Epoch, GenesisEpoch;

    struct Node {
        immutable(Options) opts;
        shared(StdSecureNet) net;
        Pubkey pkey;
    }

    Node[] nodes;
    string[] args;
   // auto args=fin.byLine.split(":");
    foreach (i, opts; node_options) {
        StdSecureNet net;
        scope (exit) {
            net = null;
        }

        if (bootkeys_path.empty) {
            net = new StdSecureNet;
            net.generateKeyPair(opts.task_names.supervisor);
        }
        else {
            WalletOptions wallet_options;
            foreach(tries; 0..3) {
            if (args.front.length != 2) {
                writefln("%$1sBad format %$3s expected nodename:pincode%$2s", RED, RESET, args.front); 
            }
                    string wallet_config_file;
            //const wallet_config_file=buildPath(bootkeys_path, args.front[0], default_wallet_config_filename);
            if (!wallet_config_file.exists) {
              //  writefln("%$1sBoot key file %
            }
            check(wallet_config_file.exists, format("Bootkey file %s not found", wallet_config_file));
            wallet_options.load(wallet_config_file);
            auto wallet_interface=WalletInterface(wallet_options);
            wallet_interface.secure_wallet.login(args[1]); 
        }
        }
        shared shared_net = (() @trusted => cast(shared) net)();

        nodes ~= Node(opts, shared_net, net.pubkey);
    }
    if (!bootkeys_path.empty) {
        return 0;
    }
    import tagion.hibon.HiBONtoText;

    if (epoch_head is Document.init) {
        foreach (n; zip(nodes, node_options)) {
            addressbook[n[0].pkey] = NodeAddress(n[1].task_names.epoch_creator);
        }
    }
    else {
        Pubkey[] keys;
        if (epoch_head.isRecord!Epoch) {
            keys = Epoch(epoch_head).active;
        }
        else {
            auto genesis = GenesisEpoch(epoch_head);

            keys = genesis.nodes;
        }

        foreach (node_info; zip(keys, node_options)) {
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
        opt.epoch_creator.timeout = 250;
        all_opts ~= opt;
    }

    if (monitor) {
        all_opts[0].monitor.enable = true;
    }

    return all_opts;
}
