module tagion.testbench.services.distributed_dart_synchronization_resilience;

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
        "check if distributed dart synchronization is resilient.",
        []);

alias FeatureContext = Tuple!(
    IsToPassBrokenAdressesToTheDistributedDartSynchronizationProcess, "IsToPassBrokenAdressesToTheDistributedDartSynchronizationProcess",
    FeatureGroup*, "result"
);

@trusted @Scenario(
    "is to pass broken adresses to the distributed dart synchronization process.",
    [])
class IsToPassBrokenAdressesToTheDistributedDartSynchronizationProcess {

    Fingerprint remote_b;
    ActorHandle[] remote_dart_handles;
    ActorHandle[] rpcserver_handles;

    ActorHandle dart_sync_handle;
    const local_db_name = "ddsr_local_dart.drt";
    string local_db_path;

    NodeRunner node_runner;

    this(NodeRunner node_runner) {
        this.node_runner = node_runner;
    }

    @Given("an empty local database.")
    Document database() {
        thisActor.task_name = "distributed_dart_synchronization_resilience_task";
        register(thisActor.task_name, thisTid);

        local_db_path = buildPath(env.bdd_log, __MODULE__, local_db_name);
        if (local_db_path.exists) {
            local_db_path.remove;
        }

        auto net = createSecureNet;
        net.generateKeyPair("dartnet very secret");
        DART.create(local_db_path, net.hash);
        return result_ok;
    }

    @Given("multiple remote nodes with broken addresses mixed up with correct ones.")
    Document ones() {
        auto net = createSecureNet;
        net.generateKeyPair("very_secret");

        const genesis_doc = node_runner.getGenesisDoc;

        auto factory = RecordFactory(net.hash);
        auto recorder = factory.recorder;
        recorder.insert(genesis_doc, Archive.Type.ADD);

        TagionBill[] bills;
        foreach (i; 0 .. 100) {
            bills ~= TagionBill(1000.TGN, currentTime, Pubkey([1, 2, 3, 4]), null);
        }
        recorder.insert(bills, Archive.Type.ADD);

        const genesis_dart_path = "genesis_dart.drt";

        DARTFile.create(genesis_dart_path, net.hash);
        auto db = new DART(net.hash, genesis_dart_path);
        db.modify(recorder);

        string[] pins;
        const node_data_paths = node_runner.createNodesData(genesis_dart_path, pins);

        const dbin = env.dbin;
        node_runner.spawnNodes(dbin, pins, node_data_paths);

        import std.random : randomShuffle;
        import std.algorithm : min;
        import std.array : array;

        SockAddresses sock_addrs;
        sock_addrs.sock_addrs = node_runner.collectDartAdresses;

        randomShuffle(sock_addrs.sock_addrs);

        auto broken_addrs_max = 3;
        foreach (i; 0 .. min(broken_addrs_max, sock_addrs.sock_addrs.length)) {
            sock_addrs.sock_addrs[i] = "abstract://dart_sync_broken";
        }
        writefln("sock_addrs: %s", sock_addrs.sock_addrs);

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

    @When("we run the synchronization.")
    Document synchronization() {
        auto dart_sync = dartSyncRR();
        dart_sync_handle.send(dart_sync);
        immutable journal_filenames = receiveOnlyTimeout!(dart_sync.Response, immutable(char[])[])(
            env.DISTRIBUTION_TIMEOUT!uint.seconds);

        auto dart_replay = dartReplayRR();
        dart_sync_handle.send(dart_replay, immutable(DARTSynchronization.ReplayFiles)(
                journal_filenames[1]));
        receiveOnlyTimeout!(dart_replay.Response, bool)(env.DISTRIBUTION_TIMEOUT!uint.seconds);
        return result_ok;
    }

    @Then("we check that local database is synchronized.")
    Document isSynchronized() {
        auto dart_compare = dartCompareRR();
        (() @trusted => dart_sync_handle.send(dart_compare))();
        immutable result = receiveOnlyTimeout!(dart_compare.Response, immutable(bool))(
            env.DISTRIBUTION_TIMEOUT!uint.seconds);

        log("Check that bullseyes match %s", result[1]);
        check(result[1], "bullseyes match");
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
    node_runner.setupMode1Options("dart_sync");

    auto distributed_dart_synchronization_resilience_feature = automation!(mixin(__MODULE__));
    auto distributed_dart_synchronization_resilience_handler = distributed_dart_synchronization_resilience_feature
        .IsToPassBrokenAdressesToTheDistributedDartSynchronizationProcess(node_runner);
    distributed_dart_synchronization_resilience_feature.run;

    scope (exit)
        distributed_dart_synchronization_resilience_handler.stopActor();
    return 0;
}
