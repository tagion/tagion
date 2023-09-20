module tagion.testbench.services.DARTService;

import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.actor;
import tagion.services.DART;
import tagion.services.messages;
import std.stdio;
import std.path;
import std.file : exists, remove;
import std.algorithm;
import std.array;
import tagion.testbench.dart.dart_helper_functions;
import tagion.dart.Recorder;
import tagion.utils.pretend_safe_concurrency;
import tagion.dart.DARTBasic : DARTIndex;

// import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import std.random;
import tagion.hibon.HiBONRecord;
import tagion.basic.Types;
import tagion.communication.HiRPC;
import tagion.dart.DARTcrud : dartRead, dartBullseye;

enum feature = Feature(
            "see if we can read and write trough the dartservice",
            []);

alias FeatureContext = Tuple!(
        WriteAndReadFromDartDb, "WriteAndReadFromDartDb",
        FeatureGroup*, "result"
);

@safe @Scenario("write and read from dart db",
        [])
class WriteAndReadFromDartDb {

    DARTServiceHandle handle;
    SecureNet net;
    DARTOptions opts;
    Mt19937 gen;
    RandomArchives random_archives;
    Document[] docs;
    RecordFactory.Recorder insert_recorder;

    struct SimpleDoc {
        ulong n;
        mixin HiBONRecord!(q{
            this(ulong n) {
                this.n = n;
            }
        });
    }

    this(DARTOptions opts) {

        this.opts = opts;
        net = new StdSecureNet();
        net.generateKeyPair("very secret");

        gen = Mt19937(1234);

    }

    @Given("I have a dart db")
    Document dartDb() {
        if (opts.dart_filename.exists) {
            opts.dart_filename.remove;
        }

        DART.create(opts.dart_filename, net);
        return result_ok;
    }

    @Given("I have an dart actor with said db")
    Document saidDb() {
        thisActor.task_name = "wowo";
        register("wowo", thisTid);

        handle = (() @trusted => spawn!DARTService("DartService", cast(immutable) opts, cast(immutable) net))();
        waitforChildren(Ctrl.ALIVE);

        return result_ok;
    }

    @When("I send a dartModify command with a recorder containing changes to add")
    Document toAdd() {

        random_archives = RandomArchives(gen.front, 4, 10);
        auto record_factory = RecordFactory(net);
        insert_recorder = record_factory.recorder;
        docs = (() @trusted => cast(Document[]) random_archives.values.map!(a => SimpleDoc(a).toDoc).array)();

        insert_recorder.insert(docs, Archive.Type.ADD);
        auto modify_request = dartModifyRR();
        (() @trusted => handle.send(modify_request, cast(immutable) insert_recorder))();
        const bullseye_tuple = receiveOnly!(dartModifyRR.Response, immutable(DARTIndex));

        check(bullseye_tuple[1]!is DARTIndex.init, "Bullseye not updated");

        return result_ok;
    }

    @When("I send a dartRead command to see if it has the changed")
    Document theChanged() @trusted {
        import std.exception : assumeUnique;

        auto fingerprints = docs
            .map!(d => net.dartIndex(d))
            .array;

        auto read_request = dartReadRR();
        handle.send(read_request, fingerprints);
        auto read_tuple = receiveOnly!(dartReadRR.Response, immutable(RecordFactory.Recorder));
        auto read_recorder = read_tuple[1];

        check(equal(read_recorder[].map!(a => a.filed), insert_recorder[].map!(a => a.filed)), "Data not the same");

        version (none) {
            const HiRPC hirpc;
            auto hirpc_read_request = dartHiRPCRR();
            immutable read_sender = dartRead(fingerprints, hirpc);
            handle.send(hirpc_read_request, read_sender);

            auto read_hirpc = receiveOnly!(dartHiRPCRR.Response, immutable(Document));
            auto read_hirpc_recorder = read_tuple[1];
            writeln(read_hirpc_recorder);
        }

        return result_ok;
    }

    @Then("the read recorder should be the same as the dartModify recorder")
    Document dartModifyRecorder() {
        // checked above

        handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);

        return result_ok;
    }

}
