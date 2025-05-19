/** 
 * The tagion node
**/
@description("Tagion node") module tagion.tools.neuewelle;

import core.stdc.stdlib : exit;
import core.sync.event;
import core.sys.posix.signal;
import core.sys.posix.unistd;
import core.thread;
import core.time;
import std.algorithm : filter, countUntil, map, uniq, equal, canFind, all;
import std.array;
import std.file : chdir, exists, remove;
import std.format;
import std.getopt;
import std.path;
import std.process : thisProcessID;
import std.range : iota;
import std.stdio;
import std.typecons;
import std.sumtype;

import tagion.GlobalSignals;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types : FileExtension, hasExtension;
import tagion.basic.dir;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DART;
import tagion.hibon.Document;
import tagion.logger;
import tagion.services.logger;
import tagion.services.options;
import tagion.services.subscription;
import tagion.services.messages;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.toolsexception;
import tagion.utils.Term;
import tagion.wave.common;
import tagion.script.common;
import tagion.script.namerecords;

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
        stopsignal.setIfInitialized;
        abort = true;
        printf("Received stop signal, telling services to stop\n");
    }
    catch (Exception e) {
        assert(0, format("DID NOT CLOSE PROPERLY \n %s", e));
    }
}

mixin Main!(_main, "wave");

int _main(string[] args) {
    try {
        return _neuewelle(args);
    }
    catch (Exception e) {
        error(e);
        return 1;
    }
}

int _neuewelle(string[] args) {
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

    string[] override_options;
    string network_mode_switch;

    auto main_args = getopt(args,
            "version", "Print revision information", &version_switch,
            "v|verbose", "Enable verbose print-out", &__verbose_switch,
            "O|override", "Override the config file", &override_switch,
            "option", "Set an option", &override_options,
            "k|keys", "Path to the boot-keys in mode0", &bootkeys_path,
            "n|dry", "Check the parameter without starting the network (dry-run)", &__dry_switch,
            "m|mode", "Set the node network mode [0,1,2]", &network_mode_switch,
    );

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
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
            stderr.writefln("Error when loading config file %s", config_file);
            error(e);
            return 1;
        }
    }
    else {
        local_options = Options.defaultOptions;
        stderr.writefln("No config file exits, running with default options");
    }

    // Experimental!!
    if (!override_options.empty) {
        local_options.set_override_options(override_options);
    }

    // Set the network mode
    if (!network_mode_switch.empty) {
        import std.conv;
        import std.traits;
        import std.uni;
        import std.exception;

        NetworkMode n_mode;
        bool good_conversion;

        collectException({ // Convert from string value [INTERNAL, LOCAL, PUB]
            n_mode = network_mode_switch.toUpper.to!NetworkMode;
            good_conversion = true;
        }());

        collectException({ // Convert from number [0, 1, 2]
            int mode_number = network_mode_switch.to!int;
            if (mode_number >= NetworkMode.min && mode_number <= NetworkMode.max) {
                n_mode = cast(NetworkMode) mode_number;
                good_conversion = true;
            }
        }());

        if (!good_conversion) {
            throw new ToolsException(format("Mode split should be %(%s,%) or %(%s,%)",
                    [EnumMembers!NetworkMode],
                    cast(int[])[EnumMembers!NetworkMode]
            ));
        }

        local_options.wave.network_mode = n_mode;
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
    immutable logger = LoggerService();
    auto logger_service = spawn(logger, "logger");
    log.set_logger_task(logger_service.task_name);
    writeln("logger started: ", waitforChildren(Ctrl.ALIVE));
    ActorHandle sub_handle;
    if (local_options.subscription.enable) { // Spawn logger subscription service
        immutable subopts = Options(local_options).subscription;
        sub_handle = spawn!SubscriptionService("logger_sub", subopts);
        writeln("logsub started: ", waitforChildren(Ctrl.ALIVE));
        log.registerSubscriptionTask("logger_sub");
    }

    log.task_name = baseName(program);

    ActorHandle[] supervisor_handles;

    log("Starting network in %s mode", local_options.wave.network_mode);

    final switch (local_options.wave.network_mode) {
    case NetworkMode.INTERNAL:
        import tagion.wave.mode0;

        const node_options = getMode0Options(local_options);
        /// WIP boot sync type beat
        DART[] dbs;
        foreach(node_opts; node_options) {
            Exception dart_exception;
            DART db = new DART(hash_net, node_opts.dart.dart_path, dart_exception, Yes.read_only);
            if (dart_exception) {
                throw dart_exception;
            }
            dbs ~= db;
        }
        auto perspective_db = dbs[0];
        static long epoch_number(E)(E epoch) => epoch.epoch_number;
        long perspective_epoch = getHead(perspective_db).getEpoch(perspective_db).match!epoch_number;
        writeln("Perspective ", perspective_epoch);
        foreach(db; dbs[1..$]) {
            const head = getHead(db);
            const epoch = getEpoch(head, db);
            long db_epoch = epoch.match!epoch_number;
            writefln("is node0 behind %s %s at Epoch %s", db.filename, perspective_epoch < db_epoch, db_epoch);
        }

        auto bullseyes = dbs.map!(db => db.bullseye);
        if (!bullseyes.all!(b => b == bullseyes[0])) {
            assert(0, "DATABASES must be booted with same bullseye - Abort");
        }

        pragma(msg, "FIXME: remove testing specific burried logic");
        Node[] nodes = (bootkeys_path.empty)
            ? dummy_nodestruct_for_testing(node_options) : inputKeys(fin, node_options, bootkeys_path);

        assert(!nodes.empty, "No node keys were available");

        Exception dart_exception;
        DART db = new DART(hash_net, node_options[0].dart.dart_path, dart_exception, Yes.read_only);
        if (dart_exception !is null) {
            throw dart_exception;
        }

        // Currently we just use the node records from the genesis epoch since there is no way to get the currently active nodes without going through the entire epoch chain.
        version (USE_GENESIS_EPOCH) {
            const head = TagionHead();
        }
        else {
            const head = getHead(db);
        }

        auto epoch = head.getEpoch(db);
        db.close;

        log("Booting with Epoch %J", epoch);

        auto keys = epoch.getNodeKeys();
        check(equal(keys, keys.uniq), "Duplicate node public keys in the genesis epoch");
        check(keys.length == node_options.length,
                format(
                "There was not the same amount of configured nodes as in the genesis epoch %s != %s)",
                keys.length,
                node_options.length
        )
        );

        if (dry_switch) {
            return 0;
        }

        foreach (ref n; nodes) {
            import tagion.services.supervisor;

            verbose("spawning supervisor ", n.opts.task_names.supervisor);
            supervisor_handles ~= spawn!Supervisor(n.opts.task_names.supervisor, n.opts, n.net);
        }

        log("started mode 0 net");

        break;
    case NetworkMode.LOCAL,
        NetworkMode.MIRROR:
        import tagion.services.supervisor;
        import tagion.script.common;
        import tagion.basic.Types;

        auto by_line = fin.byLine;
        // Hardcordes config path for now
        const wallet_config_file = "wallet.json";
        if (!wallet_config_file.exists) {
            error(format("Could not find wallet config file at <%s>", absolutePath(wallet_config_file)));
            break;
        }
        WalletOptions wallet_options;
        wallet_options.load(wallet_config_file);

        auto wallet_interface = WalletInterface(wallet_options);
        wallet_interface.load;

        info("Enter pin for <%s>", absolutePath(wallet_config_file));
        {
            const pin = (by_line.front.empty) ? string.init : by_line.front;
            wallet_interface.secure_wallet.login(pin);
        }

        if (!wallet_interface.secure_wallet.isLoggedin) {
            error("Could not log in");
            break;
        }
        local_options.task_names.setPrefix(wallet_interface.secure_wallet.account.name);

        good("Logged in");

        immutable opts = Options(local_options);
        shared net = cast(shared(SecureNet))(wallet_interface.secure_wallet.net.clone);
        spawn!Supervisor(local_options.task_names.supervisor, opts, net);

        break;
    }

    const shutdown_file = buildPath(base_dir.run, format("epoch_shutdown_%d", thisProcessID()));
    log.trace("Epoch Shutdown file %s", shutdown_file);

    import tagion.utils.pretend_safe_concurrency : receiveTimeout;

    while (!thisActor.stop) {
        thisActor.stop |= stopsignal.wait(100.msecs);

        receiveTimeout(Duration.zero,
                (EpochShutdown m, long shutdown_) { //
            foreach (handle; supervisor_handles) {
                handle.send(m, shutdown_);
            }
        },
                (TaskFailure tf) { thisActor.stop = true; log.fatal("Stopping because of unhandled taskfailure\n%s", tf); },
                default_handlers.expand,
        );

        try {
            if (shutdown_file.exists) {
                auto f = File(shutdown_file, "r");
                scope (exit) {
                    f.close;
                    shutdown_file.remove;
                }
                import std.conv;

                long shutdown;
                foreach (line; f.byLine) {
                    shutdown = line.to!long;
                }
                foreach (handle; supervisor_handles) {
                    handle.send(EpochShutdown(), shutdown);
                }
            }
        }
        catch (Exception e) {
            error("Error when reading epoch shutdown file");
            error(e);
        }

        // If all supervisors stopped then we stop as well
        thisActor.stop |=
            thisActor.childrenState
                .byKeyValue
                .filter!(c => canFind(c.key, local_options.task_names.supervisor))
                .all!(c => c.value is Ctrl.END);
    }

    log("Sending stop signal to supervisors");
    foreach (supervisor; supervisor_handles) {
        supervisor.prioritySend(Sig.STOP);
    }

    sub_handle.prioritySend(Sig.STOP);
    logger_service.prioritySend(Sig.STOP);
    // supervisor_handle.send(Sig.STOP);
    if (!waitforChildren(Ctrl.END, 5.seconds)) {
        log("Timed out before all services stopped");
        return 1;
    }
    log("Bye bye! ^.^");
    return 0;
}

import tagion.wave.mode0 : Node;
import tagion.tools.wallet.WalletOptions;
import tagion.tools.wallet.WalletInterface;

// Reads node pins key from stdin and uses wallet public key
Node[] inputKeys(File fin, const(Options[]) node_options, string bootkeys_path)
in (!bootkeys_path.empty, "Should specify a bootkeys path") {
    auto by_line = fin.byLine;
    enum number_of_retry = 3;

    Node[] nodes;
    foreach (i, opts; node_options) {
        SecureNet net;
        scope (exit) {
            net = null;
        }

        LoopTry: foreach (tries; 1 .. number_of_retry + 1) {
            scope (exit) {
                by_line.popFront;
            }

            verbose("Input boot key %d as nodename:pincode", i);

            try {
                net = inputKey(by_line.front, bootkeys_path);
                break LoopTry;
            }
            catch (Exception e) {
                error(e);
            }

            check(tries < number_of_retry, format("Max number of retries is %d", number_of_retry));
        }

        if (dry_switch && !bootkeys_path.empty) {
            writefln("%1$sBoot keys correct%2$s", GREEN, RESET);
        }
        shared shared_net = (() @trusted => cast(shared) net)();

        nodes ~= Node(opts, shared_net, net.pubkey);
    }

    return nodes;
}

SecureNet inputDevicPin(const(char)[] node_pin, string bootkeys_path) {
    import tagion.hibon.HiBONFile;
    import tagion.wallet.WalletRecords;
    import tagion.wallet.SecureWallet;

    const args = (node_pin.empty) ? string[].init : node_pin.split(":");

    check!ToolsException(args.length == 2, format("Bad format %s expected keyfile:pincode", node_pin));

    const key_file_path = buildPath(bootkeys_path, args[0]);
    scope DevicePIN devicepin = DevicePIN(fread(key_file_path));
    auto wallet = SecureWallet!StdSecureNet(devicepin);

    const key_pin = args[1];
    const _ = wallet.login(key_pin);
    check!ToolsException(wallet.isLoggedin, format("%1$sWrong pincode bootkey node %3$s%2$s", RED, RESET, key_file_path));

    verbose("%1$sNode %3$s successful%2$s", GREEN, RESET, args[0]);
    return wallet.net.clone;
}
