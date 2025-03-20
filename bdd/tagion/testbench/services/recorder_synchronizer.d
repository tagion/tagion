module tagion.testbench.services.recorder_synchronizer;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.tools.Basic;
import tagion.services.DART : DARTOptions, DARTService;
import std.file;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import std.exception;
import tagion.crypto.Types : Fingerprint;
import std.format;
import tagion.testbench.tools.Environment;
import std.path : buildPath, baseName, stripExtension;
import tagion.actor;
import tagion.services.DARTInterface;
import tagion.services.DARTSynchronization;
import tagion.services.TRTService;
import tagion.services.options;
import tagion.services.messages;
import tagion.utils.pretend_safe_concurrency : receive, receiveOnly, receiveTimeout, register, thisTid;
import core.time;
import std.stdio;
import tagion.dart.DARTcrud : dartBullseye, dartCheckRead, dartRead;
import tagion.testbench.actor.util;
import tagion.wave.common;
import tagion.script.common;
import std.random;
import std.datetime.stopwatch;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBON;
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.utils.Term;
import tagion.services.replicator;
import tagion.dart.Recorder;
import tagion.script.standardnames;

enum feature = Feature(
        "RecorderSynchronizer",
        []);

alias FeatureContext = Tuple!(
    ALocalNodeWithARecorderReadsDataFromARemoteNode, "ALocalNodeWithARecorderReadsDataFromARemoteNode",
    FeatureGroup*, "result"
);

@safe @Scenario("a local node with a recorder reads data from a remote node",
    [])
class ALocalNodeWithARecorderReadsDataFromARemoteNode {

    Fingerprint remote_b;
    ActorHandle[] remote_dart_handles;
    ActorHandle[] dart_interface_handles;
    ActorHandle[] replicator_handles;
    ReplicatorOptions replicator_opts;

    ActorHandle dart_sync_handle;
    TRTOptions trt_options;
    const local_db_name = "rs_local_dart.drt";
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

        auto net = new StdSecureNet;
        net.generateKeyPair("dartnet very secret");
        DART.create(local_db_path, net);

        return result_ok;
    }

    @Given("the remote node with random data")
    Document nodeWithRandomData() {
        import tagion.wave.common;

        const number_of_databases = 1;
        const number_of_archives = 10;

        DARTSyncOptions dart_sync_opts;
        dart_sync_opts.journal_path = buildPath(env.bdd_log, __MODULE__, local_db_path
                .baseName.stripExtension);
        SockAddresses sock_addrs;
        auto net = new StdSecureNet;
        net.generateKeyPair("remote dart secret");

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

        foreach (db_index; 0 .. number_of_databases) {
            Options opts;
            opts.setDefault();
            opts.setPrefix(format("rs_remote_db_%d_", db_index));

            auto remote_db_name = format("rs_remote_db_%d.drt", db_index);
            auto remote_db_path = buildPath(env.bdd_log, __MODULE__, remote_db_name);
            if (remote_db_path.exists) {
                remote_db_path.remove;
            }

            DART.create(remote_db_path, net);
            auto remote_dart = new DART(net, remote_db_path);
            auto recorder = remote_dart.recorder;

            auto tagion_head = TagionHead(TagionDomain, 0);
            recorder.add(tagion_head.toDoc);

            foreach (doc_no; document_numbers) {
                recorder.add(test_doc(doc_no));
            }
            auto fingerprint = remote_dart.modify(recorder);
            writefln("SendRecorder recorder %s: ", recorder.toPretty);
            writefln("SendRecorder fingerprint %s: ", fingerprint);
            writefln("SendRecorder current_epoch %s: ", tagion_head.current_epoch);

            auto replicator_handle = (() @trusted => spawn!ReplicatorService(
                    opts.task_names.replicator,
                    cast(immutable) replicator_opts))();

            replicator_handles ~= replicator_handle;

            (() @trusted => replicator_handle.send(SendRecorder(), cast(immutable) recorder, fingerprint, cast(
                    immutable(long)) tagion_head.current_epoch))();

            auto remote_dart_handle = (() @trusted => spawn!DARTService(
                    opts.task_names.dart,
                    cast(immutable) DARTOptions(null, remote_db_path),
                    opts.task_names,
                    cast(shared) net,
                    false))();
            remote_dart_handles ~= remote_dart_handle;

            auto dart_interface_handle = (() @trusted => spawn(
                    immutable(DARTInterfaceService)(cast(immutable) opts.dart_interface,
                    cast(immutable) opts.trt,
                    opts.task_names),
                    opts.task_names.dart_interface))();
            dart_interface_handles ~= dart_interface_handle;

            sock_addrs.sock_addrs ~= opts.dart_interface.sock_addr;
        }

        dart_sync_handle = (() @trusted => spawn!DARTSynchronization(
                TaskNames().dart_synchronization,
                cast(immutable) dart_sync_opts,
                cast(immutable) sock_addrs,
                cast(shared) net,
                local_db_path))();

        waitforChildren(Ctrl.ALIVE, 3.seconds);
        return result_ok;
    }

    @When("the local node subscribes on the remote node")
    Document onTheRemoteNode() {
        return Document();
    }

    @Then("the local node reads data from the remote node")
    Document fromTheRemoteNode() {
        auto dart_sync = dartSyncRR();
        dart_sync_handle.send(dart_sync);
        immutable journal_filenames = immutable(DARTSynchronization.ReplayFiles)(
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
        // check(dart_recorder_sync_result, "the recorder sync failed");

        return result_ok;
    }

    private void sendRecorders(ActorHandle handle) {
        import std.algorithm;
        import std.array;

        immutable(ulong[]) table = [
            0x20_21_10_30_40_50_80_90,
            0x20_21_11_30_40_50_80_90,
            0x20_21_12_30_40_50_80_90,
            0x20_21_0a_30_40_50_80_90,
        ];

        const SecureNet net = new DARTFakeNet("very_secret");

        // Generated recorders
        foreach (rec_index; 0 .. 10) {
            auto manufactor = RecordFactory(net);

            const doc = DARTFakeNet.fake_doc(0x1234_5678_0000_0000);
            auto rec = manufactor.recorder;
            rec.insert(doc, Archive.Type.ADD);

            const archs = table.map!(t => DARTFakeNet.fake_doc(t)).array;

            rec.insert(archs[0], Archive.Type.ADD);
            rec.insert(archs[3], Archive.Type.ADD);
            rec.insert(archs[1], Archive.Type.ADD);
            rec.insert(archs[2], Archive.Type.ADD);

            auto fingerprint = net.calcHash(doc);

            (() @trusted => handle.send(SendRecorder(), cast(immutable) rec, fingerprint, cast(
                    immutable(long)) rec_index))();
        }
    }

    void stopActor() {
        foreach (handle; remote_dart_handles) {
            handle.send(Sig.STOP);
        }
        foreach (handle; dart_interface_handles) {
            handle.send(Sig.STOP);
        }
        foreach (handle; replicator_handles) {
            handle.send(Sig.STOP);
        }
        dart_sync_handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
    }
}

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = buildPath(env.bdd_log, __MODULE__);
    mkdirRecurse(module_path);

    auto replicator_path = buildPath(module_path, "replicator");
    if (replicator_path.exists) {
        rmdirRecurse(replicator_path);
    }
    mkdirRecurse(replicator_path);

    auto replicator_opts = ReplicatorOptions(replicator_path);

    auto recorder_synchronizer_feature = automation!(
        tagion.testbench.services.recorder_synchronizer);

    auto recorder_synchronizer_handler = recorder_synchronizer_feature
        .ALocalNodeWithARecorderReadsDataFromARemoteNode(replicator_opts);
    recorder_synchronizer_feature.run;

    scope (exit) {
        recorder_synchronizer_handler.stopActor();
    }
    return 0;
}
