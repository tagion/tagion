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

    this(ActorHandle dart_handle, ActorHandle replicator_handle, ActorHandle trt_handle) {
        this.replicator_handle = replicator_handle;
        this.trt_handle = trt_handle;
        this.dart_handle = dart_handle;
    }

    void epoch_commit(EpochCommitRR req, immutable(long) epoch_number, immutable(RecordFactory.Recorder) recorder, immutable(SignedContract)[] signed_contracts) {
        dart_handle.send(dartModifyRR(), recorder);
        // Receive the new dart bullseye
        conc.receive((dartModifyRR.Response _, Fingerprint eye) {
            replicator_handle.send(Replicate(), recorder, eye, signed_contracts, epoch_number);

            // Recveive the new recorder block fingerprint
            conc.receive((Replicate.Response, Fingerprint block_frint) {

                // Send it back to the transcript service
                req.respond(eye, block_frint);
            });
        });

        if(trt_handle.isActive) {
            trt_handle.send(trtModify(), recorder, signed_contracts, long(epoch_number));
        }
    }

    void task() {
        run(&epoch_commit);
    }
}
