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
import tagion.services.DARTSyncService;
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
    ActorHandle[] handles;

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
        DART.create(local_db_path, net.hash);

        return result_ok;
    }

    @Given("we have multiple remote databases.")
    Document remoteDatabases() {
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
        opts.setDefault();
        foreach (db_index; 0 .. number_of_databases) {
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
            auto tagion_head = TagionHead(TagionDomain, 0);
            recorder.add(tagion_head.toDoc);
            foreach (doc_no; document_numbers) {
                recorder.add(test_doc(doc_no));
            }
            remote_dart.modify(recorder);

            immutable prefix = format("Node_%s", db_index);
            immutable task_names = TaskNames(prefix);
            addressbook.set(new NetworkNodeRecord(net.pubkey, task_names.node_interface));
            opts.task_names = task_names;

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
        dart_sync_handle.send(dartSyncRR());
        immutable journal_filenames = immutable(DARTSyncService.ReplayFiles)(
            receiveOnlyTimeout!(dartSyncRR.Response, immutable(char[])[])[1]);

        dart_sync_handle.send(dartReplayRR(), journal_filenames);
        auto dart_replay_result = receiveOnlyTimeout!(dartReplayRR.Response, bool)[1];
        writefln("dart_replay_result %s", dart_replay_result);

        check(dart_replay_result, "Database has been synchronized.");
        return result_ok;
    }

    @Then("we check that bullseyes match.")
    Document bullseyesMatch() {
        (() @trusted => dart_sync_handle.send(dartCompareRR()))();
        immutable result = receiveOnlyTimeout!(dartCompareRR.Response, immutable(bool))[1];

        writefln("Check that bullseyes match %s", result);
        check(result, "bullseyes match");
        return result_ok;
    }

    void stopActor() {
        foreach (handle; handles) {
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
    auto dart_synchronization_feature = automation!(tagion.testbench.services.dart_synchronization);

    auto dart_synchronization_handler = dart_synchronization_feature
        .IsToSynchronizeTheLocalDatabaseWithMultipleRemoteDatabases;

    dart_synchronization_feature.run;

    scope (exit)
        dart_synchronization_handler.stopActor();
    return 0;
}
