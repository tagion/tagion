module tagion.services.epoch_commit;

@safe:

import tagion.actor;
import tagion.script.common;
import tagion.dart.Recorder;
import tagion.crypto.Types;
import tagion.services.messages;
import tagion.services.tasknames;
import conc = tagion.utils.pretend_safe_concurrency;


struct EpochCommit {
    ActorHandle dart_handle;
    ActorHandle trt_handle;
    ActorHandle replicator_handle;
    bool trt_enable;

    this(immutable(TaskNames) tn, immutable(bool) trt_enable) {
        replicator_handle = ActorHandle(tn.replicator);
        trt_handle = ActorHandle(tn.trt);
        dart_handle = ActorHandle(tn.dart);
        this.trt_enable = trt_enable;
    }

    void epoch_commit(EpochCommitRR req, immutable(long) epoch_number, immutable(RecordFactory.Recorder) recorder, immutable(SignedContract)[] signed_contracts) {
        dart_handle.send(dartModifyRR(), recorder);
        conc.receive((dartModifyRR.Response _, Fingerprint eye) {
            replicator_handle.send(SendRecorder(), recorder, eye, signed_contracts, epoch_number);
            req.respond(eye);
        });

        if(trt_enable) {
            trt_handle.send(trtModify(), recorder, signed_contracts, long(epoch_number));
        }
    }

    void task() {
        run(&epoch_commit);
    }
}
