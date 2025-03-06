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

    ActorHandle dart_sync_handle;
    TRTOptions trt_options;
    const local_db_name = "local_dart.drt";
    string local_db_path;

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
        import std.random;
        import std.datetime.stopwatch;
        import tagion.hibon.HiBONRecord;
        import tagion.dart.DARTFakeNet : DARTFakeNet;
        import tagion.utils.Term;

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
            opts.setPrefix(format("remote_db_%d_", db_index));

            auto remote_db_name = format("remote_db_%d.drt", db_index);
            auto remote_db_path = buildPath(env.bdd_log, __MODULE__, remote_db_name);
            if (remote_db_path.exists) {
                remote_db_path.remove;
            }

            DART.create(remote_db_path, net);
            auto remote_dart = new DART(net, remote_db_path);

            auto recorder = remote_dart.recorder;
            foreach (doc_no; document_numbers) {
                recorder.add(test_doc(doc_no));
            }
            remote_dart.modify(recorder);

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
                TaskNames()
                .dart_synchronization,
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
        auto dart_recorder_sync = dartRecorderSyncRR();
        dart_sync_handle.send(dart_recorder_sync);
        immutable result = receiveOnlyTimeout!(dart_recorder_sync.Response, immutable(bool))[1];

        writefln("Is local database up to date %s", result);
        check(result, "the recorder sync failed");

        return result_ok;
    }

    void stopActor() {
    }
}

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = buildPath(env.bdd_log, __MODULE__);
    mkdirRecurse(module_path);
    auto recorder_synchronizer_feature = automation!(
        tagion.testbench.services.recorder_synchronizer);

    auto recorder_synchronizer_handler = recorder_synchronizer_feature
        .ALocalNodeWithARecorderReadsDataFromARemoteNode;

    recorder_synchronizer_feature.run;

    scope (exit) {
        recorder_synchronizer_handler.stopActor();
    }
    return 0;
}
