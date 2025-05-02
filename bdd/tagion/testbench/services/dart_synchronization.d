module tagion.testbench.services.dart_synchronization;

import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.tools.Basic;
import tagion.testbench.tools.Environment;
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
import tagion.services.rpcserver;
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
            "is a service that synchronize the DART database with multiple nodes.",
            [
        "It should be used on node start up to ensure that local database is up-to-date.",
        "In this test scenario we require that the remote database is static (not updated)."
]);

alias FeatureContext = Tuple!(
        IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases, "IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases",
        FeatureGroup*, "result"
);

@safe @Scenario("is to synchronize the local database with multiple remote databases.",
        [])
class IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases {

    Fingerprint remote_b;
    ActorHandle[] remote_dart_handles;
    ActorHandle[] rpcserver_handles;

    ActorHandle dart_sync_handle;
    TRTOptions trt_options;
    const local_db_name = "ds_local_dart.drt";
    string local_db_path;

    @Given("we have the local database.")
    Document localDatabase() {
        thisActor.task_name = "dart_synchronization_task";
        register(thisActor.task_name, thisTid);

        local_db_path = buildPath(env.bdd_log, __MODULE__, local_db_name);
        if (local_db_path.exists) {
            local_db_path.remove;
        }

        auto net = createSecureNet;
        net.generateKeyPair("dartnet very secret");
        DART.create(local_db_path, net);

        return result_ok;
    }

    @Given("we have multiple remote databases.")
    Document remoteDatabases() {
        import std.random;
        import std.datetime.stopwatch;
        import tagion.hibon.HiBONRecord;
        import tagion.dart.DARTFakeNet : DARTFakeNet;
        import tagion.utils.Term;

        const number_of_databases = 5;
        const number_of_archives = 10;

        DARTSyncOptions dart_sync_opts;
        dart_sync_opts.journal_path = buildPath(env.bdd_log, __MODULE__, local_db_path
                .baseName.stripExtension);
        SockAddresses sock_addrs;
        auto net = createSecureNet;
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
            opts.setPrefix(format("ds_remote_db_%d_", db_index));

            auto remote_db_name = format("ds_remote_db_%d.drt", db_index);
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

            auto rpcserver_handle = (() @trusted => spawn(
                    immutable(RPCServer)(cast(immutable) opts.rpcserver,
                    cast(immutable) opts.trt,
                    opts.task_names),
                    opts.task_names.rpcserver))();
            rpcserver_handles ~= rpcserver_handle;
            sock_addrs.sock_addrs ~= opts.rpcserver.sock_addr;
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

    @When("the local database is not up-to-date.")
    Document notUptodate() {
        auto dart_compare = dartCompareRR();
        dart_sync_handle.send(dart_compare);
        immutable result = receiveOnlyTimeout!(dart_compare.Response, immutable(bool))[1];

        writefln("Is local database up to date %s", result);
        check(!result, "the local database is not up-to-date");

        return result_ok;
    }

    @Then("we run the synchronization.")
    Document theSynchronization() {
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
    Document bullseyesMatch() {
        auto dart_compare = dartCompareRR();
        (() @trusted => dart_sync_handle.send(dart_compare))();
        immutable result = receiveOnlyTimeout!(dart_compare.Response, immutable(bool))[1];

        writefln("Check that bullseyes match %s", result);
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
        waitforChildren(Ctrl.END);
    }
}

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = buildPath(env.bdd_log, __MODULE__);
    mkdirRecurse(module_path);
    auto dart_synchronization_feature = automation!(tagion.testbench.services.dart_synchronization);

    auto dart_synchronization_handler = dart_synchronization_feature
        .IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases;

    dart_synchronization_feature.run;

    scope (exit)
        dart_synchronization_handler.stopActor();
    return 0;
}
