module tagion.testbench.services.recorder_service;
// Default import list for bdd
import std.algorithm;
import std.array;
import std.random;
import std.stdio;
import std.typecons : Tuple;
import tagion.actor;
import tagion.behaviour;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.recorderchain.RecorderChain;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;
import tagion.services.messages;
import tagion.services.replicator;
import tagion.testbench.dart.dart_helper_functions;
import tagion.testbench.tools.Environment;
import tagion.utils.pretend_safe_concurrency;

enum feature = Feature(
            "Recorder chain service",
            [
        "This services should store the recorder for each epoch in chain as a file.",
        "This is an extension of the Recorder backup chain."
]);

alias FeatureContext = Tuple!(
        StoreOfTheRecorderChain, "StoreOfTheRecorderChain",
        FeatureGroup*, "result"
);

@safe @Scenario("store of the recorder chain",
        [])
class StoreOfTheRecorderChain {
    immutable(ReplicatorOptions) replicator_opts;
    SecureNet replicator_net;
    ActorHandle handle;
    Mt19937 gen;
    RandomArchives random_archives;
    RecordFactory.Recorder insert_recorder;
    Document[] docs;
    RecordFactory record_factory;
    RecorderChainBlock block;

    struct SimpleDoc {
        ulong n;
        mixin HiBONRecord!(q{
            this(ulong n) {
                this.n = n;
            }
        });
    }

    this(immutable(ReplicatorOptions) replicator_opts) {
        this.replicator_opts = replicator_opts;
        replicator_net = new StdSecureNet();
        record_factory = RecordFactory(replicator_net);
        replicator_net.generateKeyPair("recordernet very secret");
        gen = Mt19937(4321);
    }

    @Given("a epoch recorder with epoch number has been received")
    Document received() {
        thisActor.task_name = "recorder_supervisor";
        register(thisActor.task_name, thisTid);
        handle = spawn!ReplicatorService("ReplicatorService", replicator_opts);
        waitforChildren(Ctrl.ALIVE);

        random_archives = RandomArchives(gen.front, 4, 10);
        insert_recorder = record_factory.recorder;
        docs = (() @trusted => cast(Document[]) random_archives.values.map!(a => SimpleDoc(a).toDoc).array)();

        insert_recorder.insert(docs, Archive.Type.ADD);
        auto send_recorder = SendRecorder();

        Fingerprint dummy_bullseye = Fingerprint([1, 2, 3, 4]);
        block = new RecorderChainBlock(insert_recorder.toDoc, Fingerprint.init, dummy_bullseye, 0, replicator_net);

        (() @trusted => handle.send(send_recorder, cast(immutable) insert_recorder, dummy_bullseye, immutable long(0)))();

        import core.thread;
        import core.time;

        (() @trusted => Thread.sleep(5.msecs))();

        return result_ok;
    }

    @When("the recorder has been store to a file")
    Document file() @trusted {
        RecorderChainStorage storage = new RecorderChainFileStorage(replicator_opts.folder_path, replicator_net);
        RecorderChain recorder_chain = new RecorderChain(storage);

        check(recorder_chain.getLastBlock.getHash == block.getHash, "read block not the same");
        return result_ok;
    }

    @Then("the file should be checked")
    Document checked() {
        handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);
        return result_ok;
    }

}
