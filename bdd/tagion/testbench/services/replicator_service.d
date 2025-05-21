module tagion.testbench.services.replicator_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.testbench.actor.util;
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.dart.Recorder;
import tagion.crypto.Types;
import tagion.tools.Basic;
import tagion.crypto.SecureNet;
import tagion.crypto.Types : Fingerprint;
import tagion.actor;
import tagion.services.options;
import tagion.services.messages;
import tagion.services.replicator;
import tagion.script.common;
import tagion.utils.pretend_safe_concurrency : receiveOnly, register, thisTid;
import tagion.replicator.RecorderBlock;
import tagion.script.methods;

import std.typecons : Tuple;
import std.file;
import std.exception;
import std.format;
import std.path : buildPath;
import std.stdio;
import std.range;

enum feature = Feature(
            "ReplicatorService",
            []);

alias FeatureContext = Tuple!(
        ProducedRecordersAreSentForReplicationAndWritenToFiles, "ProducedRecordersAreSentForReplicationAndWritenToFiles",
        WeReceiveARecorderFromFileByASpecifiedEpochNumber, "WeReceiveARecorderFromFileByASpecifiedEpochNumber",
        FeatureGroup*, "result"
);

@safe @Scenario("produced recorders are sent for replication and writen to files.",
        [])
class ProducedRecordersAreSentForReplicationAndWritenToFiles {
    ReplicatorOptions replicator_opts;
    RecordFactory.Recorder[] recorder_payloads;
    ActorHandle replicator_handle;

    this(ReplicatorOptions replicator_opts) {
        this.replicator_opts = replicator_opts;
    }

    @Given("a list of generated recorders.")
    Document recorders() {
        import std.algorithm;
        import std.array;

        thisActor.task_name = "replicator_service_task";
        register(thisActor.task_name, thisTid);

        immutable(ulong[]) table = [
            0x20_21_10_30_40_50_80_90,
            0x20_21_11_30_40_50_80_90,
            0x20_21_12_30_40_50_80_90,
            0x20_21_0a_30_40_50_80_90,
        ];

        const net = new DARTFakeNet;

        // Generated recorders
        auto manufactor = RecordFactory(net);
        foreach (rec_index; 0 .. 10) {
            const doc = DARTFakeNet.fake_doc(0x1234_5678_0000_0000);
            auto rec = manufactor.recorder;
            rec.insert(doc, Archive.Type.ADD);

            const archs = table.map!(t => DARTFakeNet.fake_doc(t)).array;

            rec.insert(archs[0], Archive.Type.ADD);
            rec.insert(archs[3], Archive.Type.ADD);
            rec.insert(archs[1], Archive.Type.ADD);
            rec.insert(archs[2], Archive.Type.ADD);

            recorder_payloads ~= rec;
        }

        return result_ok;
    }

    @When("each generated recorder is sent using the SendRecorder method.")
    Document method() {
        immutable task_names = TaskNames();
        immutable svc_options = replicator_opts;
        replicator_handle = spawn!ReplicatorService(
                task_names.replicator, svc_options);

        waitforChildren(Ctrl.ALIVE);

        foreach (immutable long i, recorder; recorder_payloads) {
            auto mock_bullseye = Fingerprint([cast(immutable(ubyte))i]);
            replicator_handle.send(Replicate(),
                    RecordFactory.uniqueRecorder(recorder),
                    mock_bullseye,
                    (immutable(SignedContract)[]).init,
                    i
            );
            receiveOnlyTimeout!(Replicate.Response, Fingerprint);
        }

        return result_ok;
    }

    @Then("they are received and each is written to a new replicator file.")
    Document file() {
        import std.range;

        auto repFilePathRequest = repFilePathRR();
        replicator_handle.send(repFilePathRequest);
        string filepath = receiveOnlyTimeout!(repFilePathRequest.Response, string)[1];

        check(!filepath.empty, "File path is empty");

        return result_ok;
    }

    void stopActor() {
        replicator_handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
    }

}

@safe @Scenario("we receive a recorder from file by a specified epoch number.",
        [])
class WeReceiveARecorderFromFileByASpecifiedEpochNumber {

    ReplicatorOptions replicator_opts;
    ActorHandle replicator_handle;
    RecorderBlock recorder_block;

    this(ReplicatorOptions replicator_opts) {
        this.replicator_opts = replicator_opts;
    }

    @Given("the recorder stored in a file.")
    Document inAFile() {
        replicator_handle = ActorHandle(TaskNames().replicator);

        auto repFilePathRequest = repFilePathRR();
        replicator_handle.send(repFilePathRequest);
        string filepath = receiveOnlyTimeout!(repFilePathRequest.Response, string)[1];

        check(!filepath.empty, "File path is empty");

        return result_ok;
    }

    @When("we send the document with the epoch number.")
    Document theEpochNumber() {
        import tagion.script.methods;
        import tagion.communication.HiRPC;

        HiRPC hirpc = HiRPC(null);
        const recorder_read_request = readRecorder(0, hirpc);

        auto readRecorderRequest = readRecorderRR();
        replicator_handle.send(readRecorderRequest, recorder_read_request.toDoc);
        auto recorder_block_doc = receiveOnlyTimeout!(readRecorderRequest.Response, Document)[1];
        recorder_block = RecorderBlock(recorder_block_doc);

        return result_ok;
    }

    @Then("we receive a recorder related to this epoch number.")
    Document thisEpochNumber() {
        check(recorder_block.epoch_number == 0, "Epoch numbers are different");
        return result_ok;
    }

}

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = buildPath(env.bdd_log, __MODULE__);
    mkdirRecurse(module_path);

    auto replicator_path = buildPath(module_path, "replicator_service");
    if (replicator_path.exists) {
        rmdirRecurse(replicator_path);
    }
    mkdirRecurse(replicator_path);

    auto replicator_opts = ReplicatorOptions(replicator_path);

    auto replicator_service_feature = automation!(
            tagion.testbench.services.replicator_service);

    auto replicator_service_handler_1 = replicator_service_feature
        .ProducedRecordersAreSentForReplicationAndWritenToFiles(replicator_opts);
    auto replicator_service_handler_2 = replicator_service_feature
        .WeReceiveARecorderFromFileByASpecifiedEpochNumber(replicator_opts);
    replicator_service_feature.run;

    scope (exit) {
        replicator_service_handler_1.stopActor();
    }
    return 0;
}
