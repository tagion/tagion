module tagion.testbench.services.distributed_dart_synchronization;

// --- Core D modules ---
import core.thread;
import core.time;

import std.algorithm;
import std.exception;
import std.file;
import std.format;
import std.getopt;
import std.path;
import std.path : baseName, buildPath, stripExtension;
import std.process;
import std.range;
import std.stdio;
import std.typecons : Tuple;

// --- Tagion base modules ---
import tagion.actor;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART;
import tagion.services.DART : DARTOptions, DARTService;
import tagion.dart.DARTcrud : dartBullseye, dartCheckRead, dartRead;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder;
import tagion.hashgraph.Refinement;
import tagion.hibon.Document;
import tagion.logger.subscription;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.services.DARTSynchronization;
import tagion.services.TRTService;
import tagion.services.messages;
import tagion.services.nodeinterface;
import tagion.services.options;
import tagion.services.rpcserver;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.pretend_safe_concurrency : receive, receiveOnly, receiveTimeout, register, thisTid;
import tagion.wave.mode0 : dummy_nodenets_for_testing;
import tagion.logger.Logger;

enum feature = Feature(
        "is a service that synchronize the DART local database with real remote nodes.",
        [
            "It should be used on node start up to ensure that local database is up-to-date.",
            "In this test scenario we require that the remote database is static (not updated)."
        ]);

alias FeatureContext = Tuple!(
    WeRunMultipleNodesAsASeparateProgramsAndSynchronizeTheLocalDatabaseWithThem, "WeRunMultipleNodesAsASeparateProgramsAndSynchronizeTheLocalDatabaseWithThem",
    FeatureGroup*, "result"
);

@trusted @Scenario( // Does not work with @safe
    "we run multiple nodes as a separate programs and synchronize the local database with them.",
    [])
class WeRunMultipleNodesAsASeparateProgramsAndSynchronizeTheLocalDatabaseWithThem {

    Fingerprint remote_b;
    ActorHandle[] remote_dart_handles;
    ActorHandle[] rpcserver_handles;

    ActorHandle dart_sync_handle;
    TRTOptions trt_options;
    const local_db_name = "dds_local_dart.drt";
    string local_db_path;

    // Nodes.
    const(Options)[] node_opts;
    Duration timeout;
    Pid[] pids;

    this(const(Options)[] node_opts, Duration timeout) {
        this.node_opts = node_opts;
        this.timeout = timeout;
    }

    @Given("we have the empty local database.")
    Document database() {
        thisActor.task_name = "distributed_dart_synchronization_task";
        register(thisActor.task_name, thisTid);

        local_db_path = buildPath(env.bdd_log, __MODULE__, local_db_name);
        if (local_db_path.exists) {
            local_db_path.remove;
        }

        auto net = new StdSecureNet;
        net.generateKeyPair("dartnet very secret");
        DART.create(local_db_path, net);
        return result_ok;
    }

    @Given("we run multiple remote nodes with databases as a separate programs.")
    Document programs() {
        auto net = new StdSecureNet;
        net.generateKeyPair("very_secret");

        const genesis_node_settings = mk_node_settings(node_opts);
        const genesis_doc = createGenesis(genesis_node_settings, Document(), TagionGlobals.init);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;
        recorder.insert(genesis_doc, Archive.Type.ADD);

        const genesis_dart_path = "genesis_dart.drt";

        DARTFile.create(genesis_dart_path, net);
        auto db = new DART(net, genesis_dart_path);
        db.modify(recorder);

        string[] pins;
        const node_data_paths = create_nodes_data(genesis_dart_path, node_opts, pins);

        const dbin = env.dbin;
        pids = spawn_nodes(dbin, pins, node_data_paths);

        // Collect adresses.
        SockAddresses sock_addrs;
        foreach (opt; node_opts) {
            sock_addrs.sock_addrs ~= opt.rpcserver.sock_addr;
        }

        DARTSyncOptions dart_sync_opts;
        dart_sync_opts.journal_path = buildPath(env.bdd_log, __MODULE__, local_db_path
                .baseName.stripExtension);

        dart_sync_handle = (() @trusted => spawn!DARTSynchronization(
                TaskNames().dart_synchronization,
                cast(immutable) dart_sync_opts,
                cast(immutable) sock_addrs,
                cast(shared) net,
                local_db_path))();

        waitforChildren(Ctrl.ALIVE, 3.seconds);

        return result_ok;
    }

    @When("we check that local database is not up-to-date.")
    Document uptodate() {
        auto dart_compare = dartCompareRR();
        dart_sync_handle.send(dart_compare);
        immutable result = receiveOnlyTimeout!(dart_compare.Response, immutable(bool))[1];

        log("Is local database up to date %s", result);
        check(!result, "the local database is not up-to-date");

        return result_ok;
    }

    @Then("we run the local database synchronization.")
    Document synchronization() {
        auto dart_sync = dartSyncRR();
        dart_sync_handle.send(dart_sync);
        immutable journal_filenames = immutable(DARTSynchronization.ReplayFiles)(
            receiveOnlyTimeout!(dart_sync.Response, immutable(char[])[])[1]);

        auto dart_replay = dartReplayRR();
        dart_sync_handle.send(dart_replay, journal_filenames);
        auto result = receiveOnlyTimeout!(dart_replay.Response, bool)[1];

        check(result, "Database has been synchronized.");
        return result_ok;
    }

    @Then("we check that bullseyes match.")
    Document match() {
        auto dart_compare = dartCompareRR();
        (() @trusted => dart_sync_handle.send(dart_compare))();
        immutable result = receiveOnlyTimeout!(dart_compare.Response, immutable(bool))[1];

        log("Check that bullseyes match %s", result);
        check(result, "bullseyes match");
        return result_ok;
    }

    void stopActor() {
        foreach (remote_dart_handle; remote_dart_handles) {
            remote_dart_handle.send(Sig.STOP);
        }
        foreach (rpcserver_handle; rpcserver_handles) {
            rpcserver_handle.send(Sig.STOP);
        }
        dart_sync_handle.send(Sig.STOP);
        kill_waves(pids, 3.seconds);
        waitforChildren(Ctrl.END);
    }
}

mixin Main!(_main);

int _main(string[] args) {

    uint number_of_nodes = 5;
    uint timeout_secs = 100;

    auto module_path = buildPath(env.bdd_log, __MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    chdir(module_path);

    auto node_opts = getMode1Options(number_of_nodes);

    auto distributed_dart_synchronization_feature = automation!(mixin(__MODULE__));

    auto distributed_dart_synchronization_handler = distributed_dart_synchronization_feature
        .WeRunMultipleNodesAsASeparateProgramsAndSynchronizeTheLocalDatabaseWithThem(
            node_opts, timeout_secs.seconds);

    distributed_dart_synchronization_feature.run;

    scope (exit)
        distributed_dart_synchronization_handler.stopActor();
    return 0;
}

void kill_waves(Pid[] pids, Duration grace_time) {
    const begin_time = MonoTime.currTime;
    enum SIGINT = 2;
    enum SIGKILL = 9;

    Pid[size_t] alive_pids;
    foreach (i, pid; pids) {
        try {
            alive_pids[i] = pid;
            kill(pid, SIGINT);
            Thread.sleep(200.msecs);
            kill(pid, SIGINT);
            log("SIGINT: %s", pid.processID);
        }
        catch (Exception _) {
        }
    }

    while (!alive_pids.empty || MonoTime.currTime - begin_time <= grace_time) {
        Thread.sleep(200.msecs);

        foreach (i, pid; alive_pids) {
            try {
                auto proc_status = tryWait(pid);
                log("%s: %s", pid.processID, proc_status);

                if (proc_status.terminated) {
                    writeln("remove ", i);
                    alive_pids.remove(i);
                }
            }
            catch (Exception _) {
            }
        }
    }

    foreach (pid; alive_pids) {
        try {
            kill(pid, SIGKILL);
            log("SIGKILL: %s", pid.processID);
            wait(pid);
        }
        catch (Exception _) {
        }
    }
}

// Return: A range of options prefixed with the node number
const(Options)[] getMode1Options(uint number_of_nodes) {
    Options local_options;
    local_options.setDefault;
    local_options.trt.enable = false;
    local_options.wave.number_of_nodes = number_of_nodes;
    local_options.wave.network_mode = NetworkMode.LOCAL;
    local_options.epoch_creator.timeout = 300; //msecs
    local_options.wave.prefix_format = "Mode1_%s_";
    local_options.subscription.tags =
        [
            StdRefinement.epoch_created.name,
            NodeInterfaceService.node_action_event.name,
        ].join(",");

    enum base_port = 10_700;

    Options[] all_opts;
    foreach (node_n; 0 .. number_of_nodes) {
        auto opt = Options(local_options);

        const prefix_f = format(opt.wave.prefix_format, node_n);
        opt.task_names.setPrefix(prefix_f);
        opt.rpcserver.setPrefix(prefix_f);
        opt.inputvalidator.setPrefix(prefix_f);
        opt.subscription.setPrefix(prefix_f);
        opt.node_interface.node_address = format("tcp://[::1]:%s", base_port + node_n);

        all_opts ~= opt;
    }

    return all_opts;
}

import tagion.tools.boot.genesis;

// NodeSettings used to create the genesis epoch
const(NodeSettings[]) mk_node_settings(ref const(Options)[] node_opts) {
    NodeSettings[] node_settings;
    auto nodenets = dummy_nodenets_for_testing(node_opts);
    foreach (opt, node_net; zip(node_opts, nodenets)) {
        node_settings ~= NodeSettings(
            opt.task_names.epoch_creator, // Name
            node_net.pubkey,
            opt.node_interface.node_address, // Address
            
        );
    }
    return node_settings;
}

/* 
 * Creates the nodes config files and wallets 
 *
 * Params:
 *   node_opts = A list of node configuration
 * Returns: A list of directories to the node data
 */
string[] create_nodes_data(string genesis_dart_path, ref const(Options)[] node_opts, out string[] pins) {
    string[] node_paths;

    foreach (i, opt; node_opts) {
        string node_path = format("node%s", i);
        node_paths ~= node_path;
        mkdir(node_path);

        const node_dart_path = buildPath(node_path, opt.dart.dart_path);
        copy(genesis_dart_path, node_dart_path);
        writeln("Copied ", node_dart_path);

        opt.save(buildPath(node_path, "tagionwave.json"));

        WalletOptions wallet_opts;
        wallet_opts.setDefault();
        const wallet_config = buildPath(node_path, "wallet.json");
        wallet_opts.save(wallet_config);

        auto wallet_interface = WalletInterface(wallet_opts);

        string pin = format("%04s", i);
        pins ~= pin;
        // This is the passphrase used by "dummy_nodenets_for_testing()"
        wallet_interface.generateSeedFromPassphrase(opt.task_names.supervisor, pin);
        chdir(node_path);
        wallet_interface.save(recover_flag : false);
        chdir("..");
    }
    return node_paths;
}

Pid[] spawn_nodes(string dbin, string[] pins, const(string[]) node_data_paths) {
    Pid[] pids;
    foreach (pin, node_path; zip(pins, node_data_paths)) {
        const cmd = [buildPath(dbin, "testbench"), "test_wave"];
        log("run: %s", cmd);

        const pin_path = buildPath(node_path, "pin.txt");

        import file = std.file;

        file.write(pin_path, pin);
        auto pin_file = File(pin_path, "r");

        Pid pid = spawnProcess(cmd, workDir:
            node_path, stdin:
            pin_file);
        Thread.sleep(300.msecs);
        log("Started %s", pid.processID);
        pids ~= pid;
    }
    return pids;
}
