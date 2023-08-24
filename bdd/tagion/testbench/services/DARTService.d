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

// import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DART;
import std.random;
import tagion.hibon.HiBONRecord;



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
        handle = (() @trusted => spawn!DARTService("DartService", cast(immutable) opts, cast(immutable) net))();
        waitforChildren(Ctrl.ALIVE);



        return result_ok;
    }

    @When("I send a dartModify command with a recorder containing changes to add")
    Document toAdd() {


        random_archives = RandomArchives(gen.front, 100, 1000);
        auto record_factory = RecordFactory(net);
        auto recorder = record_factory.recorder;
        pragma(msg, "TESTNERTEINTRSNTRIN", typeof(random_archives.values.front));
        auto docs = random_archives.values.map!(a => SimpleDoc(a).toDoc).array;

        recorder.insert(docs, Archive.Type.ADD);



        return Document();
    }

    @When("I send a dartRead command to see if it has the changed")
    Document theChanged() {
        return Document();
    }

    @Then("the read recorder should be the same as the dartModify recorder")
    Document dartModifyRecorder() {
        return Document();
    }

}
