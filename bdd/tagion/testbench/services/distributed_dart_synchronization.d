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

import std.algorithm;
import std.array;
import std.range;
import std.format;
import std.range;
import std.stdio;
import std.path;
import std.file;
import std.exception;

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
import tagion.utils.pretend_safe_concurrency : receive, receiveOnly, receiveTimeout, register, thisTid;
import tagion.logger.Logger;
import bdd.tagion.testbench.utils.node_runner;
import tagion.script.common : TagionBill;
import tagion.utils.StdTime;
import tagion.script.TagionCurrency;
import tagion.crypto.Types;
import tagion.wallet.SecureWallet : SecureWallet;

alias StdSecureWallet = SecureWallet!StdSecureNet;

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

    NodeRunner node_runner;

    this(NodeRunner node_runner) {
        this.node_runner = node_runner;
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

        const genesis_doc = node_runner.getGenesisDoc;

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;
        recorder.insert(genesis_doc, Archive.Type.ADD);

        TagionBill[] bills;
        foreach (i; 0 .. 100) {
            bills ~= TagionBill(1000.TGN, currentTime, Pubkey([1, 2, 3, 4]), null);
        }
        recorder.insert(bills, Archive.Type.ADD);

        const genesis_dart_path = "genesis_dart.drt";

        DARTFile.create(genesis_dart_path, net);
        auto db = new DART(net, genesis_dart_path);
        db.modify(recorder);

        string[] pins;
        const node_data_paths = node_runner.createNodesData(genesis_dart_path, pins);

        const dbin = env.dbin;
        node_runner.spawnNodes(dbin, pins, node_data_paths);

        // Collect adresses.
        SockAddresses sock_addrs;
        sock_addrs.sock_addrs = node_runner.collectDartAdresses;

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
        immutable journal_filenames = receiveOnlyTimeout!(dart_sync.Response, immutable(char[])[])(
            env.DISTRIBUTION_TIMEOUT!uint.seconds);

        auto dart_replay = dartReplayRR();
        dart_sync_handle.send(dart_replay, immutable(DARTSynchronization.ReplayFiles)(
                journal_filenames[1]));
        auto result = receiveOnlyTimeout!(dart_replay.Response, bool)(
            env.DISTRIBUTION_TIMEOUT!uint.seconds);

        check(result[1], "Database has been synchronized.");
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
        foreach (remote_dart_handle; remote_dart_handles)
            remote_dart_handle.send(Sig.STOP);
        foreach (rpcserver_handle; rpcserver_handles)
            rpcserver_handle.send(Sig.STOP);
        dart_sync_handle.send(Sig.STOP);
        node_runner.killWaves(3.seconds);
        waitforChildren(Ctrl.END);
    }
}

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = buildPath(env.bdd_log, __MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    chdir(module_path);

    auto node_runner = new NodeRunner(5, 300);
    node_runner.setupMode1Options();

    auto distributed_dart_synchronization_feature = automation!(mixin(__MODULE__));
    auto distributed_dart_synchronization_handler = distributed_dart_synchronization_feature
        .WeRunMultipleNodesAsASeparateProgramsAndSynchronizeTheLocalDatabaseWithThem(node_runner);
    distributed_dart_synchronization_feature.run;

    scope (exit)
        distributed_dart_synchronization_handler.stopActor();
    return 0;
}
