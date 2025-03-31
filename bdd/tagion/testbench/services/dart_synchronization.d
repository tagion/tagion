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
        "is a service that synchronizes the DART database with another one.",
        [
            "It should be used on node start up to ensure that local database is up-to-date.",
            "In this test scenario we require that the remote database is static (not updated)."
        ]);

alias FeatureContext = Tuple!(
    IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye, "IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye", // IsToSynchronizeTheLocalDatabase, "IsToSynchronizeTheLocalDatabase",
    IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases, "IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases",
    FeatureGroup*, "result"
);

@safe @Scenario("is to connect to remote database which is up-to-date and read its bullseye.",
    [])

class IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye {
    @Given("we have a local database.")
    Document localDatabase() {
        return Document();
    }

    @Given("we have a remote node with a database.")
    Document aDatabase() {
        return Document();
    }

    @When("we read the bullseye from the remote database.")
    Document remoteDatabase() {
        return Document();
    }

    @Then("we check that the remote database is different from the local one.")
    Document localOne() {
        return Document();
    }
}

version (none) @safe @Scenario("is to synchronize the local database.",
    [])
class IsToSynchronizeTheLocalDatabase {

    Fingerprint remote_b;
    ActorHandle local_dart_handle;
    ActorHandle remote_dart_handle;
    ActorHandle dart_interface_handle;
    ActorHandle dart_sync_handle;
    DARTInterfaceOptions interface_opts;
    TRTOptions trt_options;
    const local_db_name = "local_dart.drt";
    const remote_db_name = "remote_dart.drt";
    string local_db_path;

    @Given("we have the local database.")
    Document localDatabase() {
        thisActor.task_name = "dart_synchronization_task";
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

    @Given("we have the remote database.")
    Document remoteDatabase() {
        import std.random;
        import std.datetime.stopwatch;
        import tagion.hibon.HiBONRecord;
        import tagion.dart.DARTFakeNet : DARTFakeNet;
        import tagion.utils.Term;

        const number_of_archives = 10;
        const bundle_size = 1000;

        auto remote_db_path = buildPath(env.bdd_log, __MODULE__, remote_db_name);
        if (remote_db_path.exists) {
            remote_db_path.remove;
        }

        auto net = new StdSecureNet;
        net.generateKeyPair("remote dart secret");
        DART.create(remote_db_path, net);
        auto remote_dart = new DART(net, remote_db_path);

        static struct TestDoc {
            string text;
            mixin HiBONRecord;
        }

        static const(Document) test_doc(const ulong x) {
            TestDoc _test_doc;
            _test_doc.text = format("Test document %d", x);
            return _test_doc.toDoc;
        }

        size_t count;
        auto rnd = Random(unpredictableSeed);

        foreach (no; 0 .. (number_of_archives / bundle_size) + 1) {
            count += bundle_size;
            const N = (number_of_archives < count) ? number_of_archives % bundle_size : bundle_size;
            auto recorder = remote_dart.recorder;
            foreach (i; 0 .. N) {
                const random_doc_no = uniform(ulong.min, ulong.max, rnd);
                recorder.add(test_doc(random_doc_no));
            }
            remote_dart.modify(recorder);
        }

        remote_dart_handle = (() @trusted => spawn!DARTService(
                TaskNames().dart,
                immutable(DARTOptions)(null, remote_db_path),
                TaskNames(),
                cast(shared) net,
                false))();

        interface_opts.setDefault;

        dart_interface_handle = (() @trusted => spawn(
                immutable(DARTInterfaceService)(cast(immutable) interface_opts,
                cast(immutable) trt_options,
                TaskNames()),
                TaskNames().dart_interface))();

        DARTSyncOptions dart_sync_opts;
        dart_sync_opts.journal_path = buildPath(env.bdd_log, __MODULE__, local_db_path
                .baseName.stripExtension);

        SockAddresses sock_addrs;
        sock_addrs.sock_addrs ~= interface_opts.sock_addr;

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

        check(!result, "the local database is not up-to-date");
        writefln("Is local database up to date %s", result);

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

        check(result, "bullseyes match");
        writefln("Check that bullseyes match %s", result);
        return result_ok;
    }

    void stopActor() {
        remote_dart_handle.send(Sig.STOP);
        dart_interface_handle.send(Sig.STOP);
        dart_sync_handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
    }
}

@safe @Scenario("is to synchronize the local database with multiple remote databases.",
    [])
class IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases {

    Fingerprint remote_b;
    ActorHandle[] remote_dart_handles;
    ActorHandle[] dart_interface_handles;

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

        auto net = new StdSecureNet;
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

    @When("the local database is not up-to-date.")
    Document notUptodate() {
        auto dart_compare = dartCompareRR();
        dart_sync_handle.send(dart_compare);
        immutable result = receiveOnlyTimeout!(dart_compare.Response, immutable(bool))[1];

        writefln("Is local database up to date %s", result);
        check(!result, "the local database is not up-to-date");

        return result_ok;
    }

    @Then("we check that those databases contain data.")
    Document containData() {
        return Document();
    }

    @Then("we run the synchronization.")
    Document theSynchronization() {
        auto dart_sync = dartSyncRR();
        dart_sync_handle.send(dart_sync);
        immutable journal_filenames = immutable(DARTSynchronization.ReplayFiles)(
            receiveOnlyTimeout!(dart_sync.Response, immutable(char[])[])[1]);

        // writefln("journal filenames: %s", journal_filenames);

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
        foreach (dart_interface_handle; dart_interface_handles) {
            dart_interface_handle.send(Sig.STOP);
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

    // auto dart_synchronization_handler_1 = dart_synchronization_feature
    //     .IsToSynchronizeTheLocalDatabase;
    auto dart_synchronization_handler_2 = dart_synchronization_feature
        .IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases;

    dart_synchronization_feature.run;

    scope (exit) {
        // dart_synchronization_handler_1.stopActor();
        dart_synchronization_handler_2.stopActor();
    }
    return 0;
}
