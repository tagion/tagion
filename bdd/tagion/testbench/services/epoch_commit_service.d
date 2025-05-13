module tagion.testbench.services.epoch_commit_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import std.variant;
import std.stdio;
import tagion.actor;
import tagion.services.epoch_commit;
import tagion.services.messages;
import tagion.crypto.Types;
import tagion.script.common;
import tagion.dart.Recorder;
import conc = tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "Epoch Commit Service",
            ["Check that the epoch commit service forwards all the correct request from the transcript"]);

alias FeatureContext = Tuple!(
        SendMockDataToEpochCommit, "SendMockDataToEpochCommit",
        FeatureGroup*, "result"
);

@safe
void mock_dart() {
    conc.receive((dartModifyRR req, immutable(RecordFactory.Recorder) recorder) {
         req.respond(Fingerprint.init);
         sendOwner(Msg!"ok"(), __FUNCTION__);
     },
     (Variant var) @trusted {
         writeln(var);
         sendOwner(Msg!"error"(), __FUNCTION__);
     });
}

@safe
void mock_replicator() {
    conc.receive((Replicate req,
     immutable(RecordFactory.Recorder) recorder,
     Fingerprint eye,
     immutable(SignedContract)[] signed_contracts,
     immutable(long) epoch_number
     ) {
         req.respond(Fingerprint.init);
         sendOwner(Msg!"ok"(), __FUNCTION__);
     },
     (Variant var) @trusted {
         writeln(var);
         sendOwner(Msg!"error"(), __FUNCTION__);
     });
}

@safe
void mock_trt() {
    conc.receive((trtModify _,
     immutable(RecordFactory.Recorder) recorder,
     immutable(SignedContract)[] signed_contracts,
     long epoch_number) {
         sendOwner(Msg!"ok"(), __FUNCTION__);
     },
     (Variant var) @trusted {
         writeln(var);
         sendOwner(Msg!"error"(), __FUNCTION__);
     });
}


@safe @Scenario("send mock data to epoch commit",
        [])
class SendMockDataToEpochCommit {
    ActorHandle dart;
    ActorHandle replicator;
    ActorHandle trt;
    ActorHandle epoch_commit;

    @Given("an epoch commit service a mock trt, dart and replicator")
    Document mock_services() {
        trt = ActorHandle("trt", conc.spawn(&mock_trt));
        replicator = ActorHandle("replicator", conc.spawn(&mock_replicator));
        dart = ActorHandle("dart", conc.spawn(&mock_dart));
        epoch_commit = _spawn!EpochCommit("epoch_commit", dart, replicator, trt);

        waitforChildren(Ctrl.ALIVE);

        return result_ok;
    }

    @When("#we Send mock transcript data to the epoch_commit service")
    Document service() {
        epoch_commit.send(EpochCommitRR(), (immutable(long))(0), (immutable(RecordFactory.Recorder)).init, (immutable(SignedContract)[]).init);
        return result_ok;
    }

    @Then("the mock trt, transcript and dart should receive the mock data")
    Document data() {
        import std.stdio;
        foreach(_; 0 .. 4) {
            conc.receive(
                    (EpochCommitRR.Response, Fingerprint bullseye, Fingerprint recorder_block) {
                        writeln("yay epoch commited");
                    },
                    (Msg!"ok"_, string fn) { writeln(fn); },
                    (Variant var) @trusted {
                        stderr.writeln(var);
                        throw new Exception("One of the services did not receive the correct value");
                    }
            );
        }

        epoch_commit.send(Sig.STOP);

        return result_ok;
    }

}

import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    automation!(mixin(__MODULE__)).run;
    return 0;
}
