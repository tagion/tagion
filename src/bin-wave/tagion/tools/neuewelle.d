/** 
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
import std.path : baseName, dirName;
import std.range : iota;
import std.stdio;
import std.typecons;

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

    string mode0_node_opts_path;
    string[] override_options;

    auto main_args = getopt(args,
            "version", "Print revision information", &version_switch,
            "O|override", "Override the config file", &override_switch,
            "option", "Set an option", &override_options,
            "k|keys", "Path to the boot-keys in mode0", &bootkeys_path,
            "v|verbose", "Enable verbose print-out", &__verbose_switch,
            "n|dry", "Check the parameter without starting the network (dry-run)", &__dry_switch,
            "nodeopts", "Generate single node opts files for mode0", &mode0_node_opts_path,
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

        auto node_options = getMode0Options(local_options, monitor);
        auto __net = new StdSecureNet();
        __net.generateKeyPair("dart_read_pin");

        if (!isMode0BullseyeSame(node_options, __net)) {
            assert(0, "DATABASES must be booted with same bullseye - Abort");
        }

        auto nodes = inputKeys(fin, node_options, bootkeys_path);
        if (nodes is Node[].init) {
            return 0;
        }

        Document doc = getHead(node_options[0], __net);
        // we only need to read one head since all bullseyes are the same:
        spawnMode0(node_options, supervisor_handles, nodes, doc);
        log("started mode 0 net");

        if (mode0_node_opts_path) {
            foreach (i, opt; node_options) {
                opt.save(buildPath(mode0_node_opts_path, format(opt.wave.prefix_format ~ "opts", i).setExtension(
                        FileExtension
                        .json)));
            }
        }
        break;
    case NetworkMode.LOCAL:
        import tagion.services.supervisor;
        import tagion.script.common;
        import tagion.gossip.AddressBook;
        import tagion.hibon.HiBONtoText;
        import tagion.crypto.Types;
        import std.exception : assumeUnique;
        import std.string;

        auto __net = new StdSecureNet();
        __net.generateKeyPair("OwO");
        scope (exit) {
            destroy(__net);
        }

        auto address_file = File(local_options.wave.mode1.address_book_file, "r");
        foreach (line; address_file.byLine) {
            auto pair = line.split();
            check(pair.length == 2, format("Expected only 2 fields in addresbook line\n%s", line));
            const pkey = Pubkey(pair[0].strip.decode);
            check(pkey.length == 33, "Pubkey with invalid length");
            const addr = pair[1].strip;

            addressbook[pkey] = assumeUnique(addr);
        }

        Document epoch_head = getHead(local_options, __net);

        auto genesis = GenesisEpoch(epoch_head);

        const keys = genesis.nodes;

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

Node[] inputKeys(File fin, const(Options[]) node_options, string bootkeys_path) {
    auto by_line = fin.byLine;
    enum number_of_retry = 3;

    Node[] nodes;
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
        }
        if (dry_switch && !bootkeys_path.empty) {
            writefln("%1$sBoot keys correct%2$s", GREEN, RESET);
        }
        shared shared_net = (() @trusted => cast(shared) net)();

        nodes ~= Node(opts, shared_net, net.pubkey);
    }

    if (dry_switch) {
        return Node[].init;
    }
    return nodes;
}
