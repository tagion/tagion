/** 
d
 * New wave implementation of the tagion node
**/
module tagion.tools.neuewelle;

import core.stdc.stdlib : exit;
import core.sync.event;
import core.sys.posix.signal;
import core.sys.posix.unistd;
import core.thread;
import core.time;
import std.algorithm : countUntil, map, uniq, equal;
import std.array;
import std.file : chdir, exists;
import std.format;
import std.getopt;
import std.path;
import std.range : iota;
import std.stdio;
import std.typecons;
import std.sumtype;

import tagion.GlobalSignals : segment_fault, stopsignal;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types : FileExtension, hasExtension;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.logger;
import tagion.services.locator;
import tagion.services.logger;
import tagion.services.options;
import tagion.services.subscription;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.toolsexception;
import tagion.utils.Term;
import tagion.wave.common;
import tagion.script.common;
import tagion.script.namerecords;

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
    bool monitor;

    string[] override_options;

    auto main_args = getopt(args,
            "version", "Print revision information", &version_switch,
            "O|override", "Override the config file", &override_switch,
            "option", "Set an option", &override_options,
            "k|keys", "Path to the boot-keys in mode0", &bootkeys_path,
            "v|verbose", "Enable verbose print-out", &__verbose_switch,
            "n|dry", "Check the parameter without starting the network (dry-run)", &__dry_switch,
            "m|monitor", "Enable the monitor", &monitor,
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
            const index = option.countUntil(":");
            assert(index > 0, format("Option '%s' invalid, missing key:value", option));
            string[] key = option[0 .. index].split(".");
            string value = option[index + 1 .. $];
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
    ActorHandle sub_handle;
    { // Spawn logger subscription service
        immutable subopts = Options(local_options).subscription;
        sub_handle = spawn!SubscriptionService("logger_sub", subopts);
        writeln("logsub started: ", waitforChildren(Ctrl.ALIVE));
        log.registerSubscriptionTask("logger_sub");
    }

    log.task_name = baseName(program);

    locator_options = new immutable(LocatorOptions)(20, 5);
    ActorHandle[] supervisor_handles;

    final switch (local_options.wave.network_mode) {
    case NetworkMode.INTERNAL:
        import tagion.wave.mode0;
        import tagion.gossip.AddressBook;

        const node_options = getMode0Options(local_options, monitor);

        auto __net = new StdSecureNet();
        __net.generateKeyPair("dart_read_pin");

        if (!isMode0BullseyeSame(node_options, __net)) {
            assert(0, "DATABASES must be booted with same bullseye - Abort");
        }


        Node[] nodes = (bootkeys_path.empty)
            ? dummy_nodestruct_for_testing(node_options) 
            : inputKeys(fin, node_options, bootkeys_path);

        assert(!nodes.empty, "No node keys were available");

        version (USE_GENESIS_EPOCH) {
            import tagion.dart.DART;

            Exception dart_exception;
            DART db = new DART(__net, node_options[0].dart.dart_path, dart_exception, Yes.read_only);
            if (dart_exception !is null) {
                throw dart_exception;
            }
            scope (exit) {
                db.close;
            }

            const head = TagionHead("tagion", 0);
            auto epoch = head.getEpoch(db, __net);
        }
        else {
            auto epoch = getCurrentEpoch(node_options[0].dart.dart_path, __net);
        }

        auto keys = epoch.getNodeKeys();
        check(equal(keys, keys.uniq), "Duplicate node public keys in the genesis epoch");
        check(keys.length == node_options.length, format("There was not the same amount of configured nodes as in the genesis epoch %s != %s)", keys.length, node_options.length));

        if (!local_options.wave.address_file.empty) {
            // Read from text file. Will probably be removed
            addressbook.set(readAddressFile(local_options.wave.address_file));
        }
        else {
            // New version reads the addresses properly from dart
            // However is incompatble with older darts were not set properly
            version (MODE0_ADDRESS_DART) {
                addressbook.set(readNNRFromDart(node_options[0].dart.dart_path, keys, __net));
            }
            else { // Old methods sets, address via task name from config file
                import std.range;
                foreach (key, opt; zip(keys, node_options)) {
                    verbose("adding Address ", key);
                    addressbook[key] = new NetworkNodeRecord(key, opt.task_names.epoch_creator);
                }
            }
        }

        if (dry_switch) {
            return 0;
        }

        // we only need to read one head since all bullseyes are the same:
        spawnMode0(supervisor_handles, nodes);
        log("started mode 0 net");

        break;
    case NetworkMode.LOCAL:
        import tagion.services.supervisor;
        import tagion.script.common;
        import tagion.gossip.AddressBook;
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

        good("Logged in");
        StdSecureNet __net;
        __net = cast(StdSecureNet) wallet_interface.secure_wallet.net.clone;
        scope (exit) {
            destroy(__net);
        }

        auto epoch = getCurrentEpoch(local_options.dart.dart_path, __net);
        auto keys = epoch.getNodeKeys;

        if (!local_options.wave.address_file.empty) {
            // Read from text file. Will probably be removed
            addressbook.set(readAddressFile(local_options.wave.address_file));
        }
        else {
            addressbook.set(readNNRFromDart(local_options.dart.dart_path, keys, __net));
        }

        foreach (key; keys) {
            check(addressbook.exists(key), format("No address for node with pubkey %s", key.encodeBase64));
        }

        immutable opts = Options(local_options);
        auto net = cast(shared(StdSecureNet))(__net.clone);
        spawn!Supervisor(local_options.task_names.supervisor, opts, net);

        break;
    case NetworkMode.PUB:
        assert(0, "NetworkMode not supported");
    }

    if (waitforChildren(Ctrl.ALIVE, Duration.max)) {
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
    logger_service.send(Sig.STOP);

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
in(!bootkeys_path.empty, "Should specify a bootkeys path")
{
    auto by_line = fin.byLine;
    enum number_of_retry = 3;

    Node[] nodes;
    foreach (i, opts; node_options) {
        StdSecureNet net;
        scope (exit) {
            net = null;
        }

        WalletOptions wallet_options;
        LoopTry: foreach (tries; 1 .. number_of_retry + 1) {
            verbose("Input boot key %d as nodename:pincode", i);
            const args = (by_line.front.empty) ? string[].init : by_line.front.split(":");
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
