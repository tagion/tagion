module tagion.testbench.services.recorder_synchronizer;

import std.algorithm;
import std.datetime.stopwatch;
import std.exception;
import std.file;
import std.format;
import std.path : buildPath, baseName, stripExtension;
import std.random;
import std.stdio;
import std.typecons : Tuple;
import core.time;

import tagion.actor;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART;
import tagion.dart.DARTcrud : dartBullseye, dartCheckRead, dartRead;
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.dart.Recorder;
import tagion.errors.tagionexceptions;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.services.DART : DARTOptions, DARTService;
import tagion.services.rpcserver;
import tagion.services.DARTSyncService;
import tagion.services.TRTService;
import tagion.services.messages;
import tagion.services.options;
import tagion.services.replicator;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import tagion.utils.Term;
import tagion.utils.pretend_safe_concurrency : receive, receiveOnly, receiveTimeout, register, thisTid;
import tagion.wave.common;

enum feature = Feature("RecorderSynchronizer", []);

alias FeatureContext = Tuple!(
    ALocalNodeWithARecorderReadsDataFromARemoteNode, "ALocalNodeWithARecorderReadsDataFromARemoteNode",
    FeatureGroup*, "result"
);

@safe
@Scenario("a local node with a recorder reads data from a remote node", [])
class ALocalNodeWithARecorderReadsDataFromARemoteNode {

    Fingerprint remote_b;
    ActorHandle[] handles;
    ActorHandle dart_sync_handle;
    ReplicatorOptions replicator_opts;

    TRTOptions trt_options;
    enum local_db_name = "rs_local_dart.drt";
    string local_db_path;

    this(ReplicatorOptions replicator_opts) {
        this.replicator_opts = replicator_opts;
    }

    @Given("the empty local node")
    Document theEmptyLocalNode() {
        thisActor.task_name = "recorder_synchronize_task";
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

    @Given("the remote node with random data")
    Document nodeWithRandomData() {
        import std.random;
        import std.datetime.stopwatch;
        import tagion.hibon.HiBONRecord;
        import tagion.dart.DARTFakeNet : DARTFakeNet;
        import tagion.utils.Term;
        import tagion.gossip.AddressBook;
        import tagion.script.common;
        import tagion.wave.common;
        import std.range;
        import tagion.services.mode0_nodeinterface;
        import tagion.script.standardnames;
        import tagion.script.namerecords;

        const number_of_databases = 5;
        const number_of_archives = 10;

        auto journal_path = buildPath(env.bdd_log, __MODULE__, local_db_path
                .baseName.stripExtension);
        shared(AddressBook) addressbook = new shared(AddressBook);

        static struct TestDoc {
            string text;
            mixin HiBONRecord;
        }

        static const(Document) test_doc(const ulong x) {
            TestDoc _test_doc;
            _test_doc.text = format("Test document %d", x);
            return _test_doc.toDoc;
        }

        ulong[] document_numbers;
        auto rnd = Random(unpredictableSeed);

        foreach (_; 0 .. number_of_archives) {
            document_numbers ~= uniform(ulong.min, ulong.max, rnd);
        }

        Options opts;
        foreach (db_index; 0 .. number_of_databases) {
            opts.setDefault();
            opts.setPrefix(format("ds_remote_db_%d_", db_index));

            auto remote_db_name = format("ds_remote_db_%d.drt", db_index);
            auto remote_db_path = buildPath(env.bdd_log, __MODULE__, remote_db_name);
            if (remote_db_path.exists) {
                remote_db_path.remove;
            }

            auto net = createSecureNet;
            net.generateKeyPair("remote dart secret");

            DART.create(remote_db_path, net.hash);
            auto remote_dart = new DART(net.hash, remote_db_path);

            auto recorder = remote_dart.recorder;
            auto tagion_head = TagionHead(TagionDomain, db_index);
            recorder.add(tagion_head.toDoc);
            foreach (doc_no; document_numbers) {
                recorder.add(test_doc(doc_no));
            }
            auto fingerprint = remote_dart.modify(recorder);

            immutable prefix = format("Node_%s", db_index);
            immutable task_names = TaskNames(prefix);
            addressbook.set(new NetworkNodeRecord(net.pubkey, task_names.node_interface));
            opts.task_names = task_names;

            immutable local_replicator_opts = replicator_opts;
            auto replicator_handle = spawn!ReplicatorService(
                opts.task_names.replicator,
                local_replicator_opts);
            handles ~= replicator_handle;

            TaskNames tn = opts.task_names;
            tn.node_interface = addressbook[net.pubkey].get.address;

            auto remote_dart_handle = (() @trusted => spawn!DARTService(
                    opts.task_names.dart,
                    cast(immutable) DARTOptions(null, remote_db_path),
                    cast(shared) net,
            ))();
            handles ~= remote_dart_handle;

            auto rpcserver_handle = (() @trusted => spawn(
                    immutable(RPCServer)(cast(immutable) opts.rpcserver,
                    cast(immutable) opts.trt,
                    opts.task_names),
                    opts.task_names.rpcserver))();
            handles ~= rpcserver_handle;

            auto node_interface_handle = (() @trusted => _spawn!Mode0NodeInterfaceService(
                    tn.node_interface,
                    cast(shared) net,
                    addressbook,
                    opts.task_names,
            ))();
            handles ~= node_interface_handle;
            waitforChildren(Ctrl.ALIVE, 3.seconds);

            replicator_handle.send(Replicate(), RecordFactory.uniqueRecorder(recorder), fingerprint, (
                    immutable(SignedContract)[]).init, immutable(long)(tagion_head.current_epoch));
            receiveOnlyTimeout!(Replicate.Response, Fingerprint);
        }

        auto dart_sync_net = createSecureNet;
        dart_sync_net.generateKeyPair("remote dart secret");

        dart_sync_handle = (() @trusted => spawn!DARTSyncService(
                opts.task_names.dart_synchronization,
                cast(immutable) journal_path,
                cast(shared) dart_sync_net,
                local_db_path,
                addressbook,
                opts.task_names))();
        handles ~= dart_sync_handle;
        waitforChildren(Ctrl.ALIVE, 3.seconds);
        return result_ok;
    }

    @When("the local node subscribes on the remote node")
    Document onTheRemoteNode() {
        // The subscription is not needed as the local
        // node communicates with the remote node much earlier.
        // So just return result_ok.
        return result_ok;
    }

    @Then("the local node reads data from the remote node")
    Document fromTheRemoteNode() {
        auto dart_sync = dartSyncRR();
        dart_sync_handle.send(dart_sync);
        immutable journal_filenames = immutable(DARTSyncService.ReplayFiles)(
            receiveOnlyTimeout!(dart_sync.Response, immutable(char[])[])[1]);

        auto dart_replay = dartReplayRR();
        dart_sync_handle.send(dart_replay, journal_filenames);
        auto dart_replay_result = receiveOnlyTimeout!(dart_replay.Response, bool)[1];
        writefln("dart_replay_result %s", dart_replay_result);

        auto dart_recorder_sync = syncRecorderRR();
        dart_sync_handle.send(dart_recorder_sync);
        immutable dart_recorder_sync_result = receiveOnlyTimeout!(
            dart_recorder_sync.Response, immutable(bool))[1];
        writefln("Is local database up to date %s", dart_recorder_sync_result);

        return result_ok;
    }

    void stopActor() {
        foreach (handle; handles)
            handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
    }
}

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = buildPath(env.bdd_log, __MODULE__);
    mkdirRecurse(module_path);

    auto replicator_path = buildPath(module_path, "replicator_service");
    if (replicator_path.exists)
        rmdirRecurse(replicator_path);
    mkdirRecurse(replicator_path);

    auto replicator_opts = ReplicatorOptions(replicator_path);

    auto recorder_synchronizer_feature = automation!(
        tagion.testbench.services.recorder_synchronizer);

    auto recorder_synchronizer_handler = recorder_synchronizer_feature
        .ALocalNodeWithARecorderReadsDataFromARemoteNode(replicator_opts);

    recorder_synchronizer_feature.run;

    scope (exit)
        recorder_synchronizer_handler.stopActor();
    return 0;
}
