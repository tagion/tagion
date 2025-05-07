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
import tagion.utils.pretend_safe_concurrency : receiveOnly, register, thisTid;
import tagion.replicator.RecorderBlock;
import tagion.replicator.RecorderCrud;

import std.typecons : Tuple;
import std.file;
import std.exception;
import std.format;
import std.path : buildPath;
import std.stdio;

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

    struct RecorderPayload {
        RecordFactory.Recorder recorder;
        Fingerprint fingerprint;
        long epoch_number;
    }

    ReplicatorOptions replicator_opts;
    RecorderPayload[] recorder_payloads;
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

            auto fingerprint = net.calc(doc);
            auto payload = RecorderPayload(rec, fingerprint, rec_index);
            recorder_payloads ~= payload;
        }

        return result_ok;
    }

    @When("each generated recorder is sent using the SendRecorder method.")
    Document method() {
        immutable task_names = TaskNames();
        replicator_handle = (() @trusted => spawn!ReplicatorService(
                task_names.replicator,
                cast(immutable) replicator_opts))();

        foreach (payload; recorder_payloads) {
            (() @trusted => replicator_handle.send(SendRecorder(),
                    cast(immutable) payload.recorder,
                    payload.fingerprint,
                    cast(immutable(long)) payload.epoch_number))();
        }

        waitforChildren(Ctrl.ALIVE);
        return result_ok;
    }

    @Then("they are received and each is written to a new replicator file.")
    Document file() {
        import std.range;

        auto repFilePathRequest = repFilePathRR();
        replicator_handle.send(repFilePathRequest);
        auto filepath = receiveOnlyTimeout!(repFilePathRequest.Response, immutable(char)[])[1];

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
    EpochParam epoch_param;
    RecorderBlock recorder_block;

    this(ReplicatorOptions replicator_opts) {
        this.replicator_opts = replicator_opts;
    }

    @Given("the recorder stored in a file.")
    Document inAFile() {
        import std.range;

        thisActor.task_name = "replicator_service_task";
        register(thisActor.task_name, thisTid);

        immutable task_names = TaskNames();
        replicator_handle = (() @trusted => spawn!ReplicatorService(
                task_names.replicator,
                cast(immutable) replicator_opts))();

        waitforChildren(Ctrl.ALIVE);

        auto repFilePathRequest = repFilePathRR();
        replicator_handle.send(repFilePathRequest);
        auto filepath = receiveOnlyTimeout!(repFilePathRequest.Response, immutable(char)[])[1];

        check(!filepath.empty, "File path is empty");

        return result_ok;
    }

    @Given("a hibon with an epoch number as a document.")
    Document asADocument() {
        epoch_param = EpochParam(cast(long) 0);
        return result_ok;
    }

    @When("we send the document with the epoch number.")
    Document theEpochNumber() {
        import tagion.replicator.RecorderCrud;
        import tagion.communication.HiRPC;

        HiRPC hirpc = HiRPC(null);
        const recorder_read_request = hirpc.readRecorder(epoch_param);

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

    void stopActor() {
        replicator_handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
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
        replicator_service_handler_2.stopActor();
    }
    return 0;
}
