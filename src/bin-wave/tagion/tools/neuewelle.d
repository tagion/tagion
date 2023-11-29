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
import tagion.services.transcript : graceful_shutdown;


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

mixin Main!(_main, "wave");

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
    File fin = stdin; /// Console input for the bootkeys
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

    string mode0_node_opts_path;
    string[] override_options;

    auto main_args = getopt(args,
            "version", "Print revision information", &version_switch,
            "O|override", "Override the config file", &override_switch,
            "option", "Set an option", &override_options,
            "k|keys", "Path to the boot-keys in mode0", &bootkeys_path,
            "v|verbose", "Enable verbose print-out", &__verbose_switch,
            "n|dry", "Check the parameter without staring the network (dry-run)", &__dry_switch,
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

    enum default_wave_config_filename = "tagionwave".setExtension(FileExtension.json);
    const user_config_file = args.countUntil!(file => file.hasExtension(FileExtension.json) && file.exists);
    auto config_file = (user_config_file < 0) ? default_wave_config_filename : args[user_config_file];

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


            pragma(msg, "fixme(phr): count the keys up hardcoded to be genesis atm");
            DARTIndex epoch_index = __net.dartKey(StdNames.epoch, long(0));
            writefln("epoch index is %(%02x%)", epoch_index);

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

    if (waitforChildren(Ctrl.ALIVE, 50.seconds)) {
        log("alive");
        bool signaled;
        import tagion.utils.pretend_safe_concurrency : receiveTimeout;
        import core.atomic;

        do {
            signaled = stopsignal.wait(100.msecs);
            if (!signaled) {
                if (local_options.wave.fail_fast) {
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
        while (!signaled && graceful_shutdown.atomicLoad() != local_options.wave.number_of_nodes);
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
    auto by_line = fin.byLine;
    enum number_of_retry = 3;
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
            LoopTry: foreach (tries; 1 .. number_of_retry + 1) {
                verbose("Input boot key %d as nodename:pincode", i);
                const args = by_line.front.split(":");
                by_line.popFront;
                if (args.length != 2) {
                    writefln("%1$sBad format %3$s expected nodename:pincode%2$s", RED, RESET, args.front);
                }
                //string wallet_config_file;
                const wallet_config_file = buildPath(bootkeys_path, args[0]).setExtension(FileExtension.json);
                writeln("Looking for " ~ wallet_config_file);
                verbose("Wallet path %s", wallet_config_file);
                if (!wallet_config_file.exists) {
                    writefln("%1$sBoot key file %3$s not found%2$s", RED, RESET, wallet_config_file);
                    writefln("Try another node name");
                }
                else {
                    verbose("Load config");
                    wallet_options.load(wallet_config_file);
                    auto wallet_interface = WalletInterface(wallet_options);
                    verbose("Load wallet");
                    wallet_interface.load;

                    const loggedin = wallet_interface.secure_wallet.login(args[1]);
                    if (wallet_interface.secure_wallet.isLoggedin) {
                        verbose("%1$sNode %3$s successfull%2$s", GREEN, RESET, args[0]);
                        net = cast(StdSecureNet) wallet_interface.secure_wallet.net.clone;
                        break LoopTry;
                    }
                    else {
                        writefln("%1$sWrong pincode bootkey %3$s node %4$s%2$s", RED, RESET, i, args[0]);
                    }
                }
                check(tries < number_of_retry, format("Max number of reties is %d", number_of_retry));

            }
        }
        if (dry_switch && !bootkeys_path.empty) {
            writefln("%1$sBoot keys correct%2$s", GREEN, RESET);
        }
        shared shared_net = (() @trusted => cast(shared) net)();

        nodes ~= Node(opts, shared_net, net.pubkey);
    }
    if (dry_switch) {
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
            assert(0, "not supported to boot from epoch yet");
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
        all_opts ~= opt;
    }

    if (monitor) {
        all_opts[0].monitor.enable = true;
    }

    return all_opts;
}
