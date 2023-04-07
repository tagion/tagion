module tagion.testbench.dart.insert_remove_stress;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.file : mkdirRecurse;
import std.stdio;
import std.format;
import tagion.utils.Random : RandomArchives;
import std.random;
import std.range;
import std.algorithm;
import std.datetime.stopwatch;


// dart
import tagion.dart.DARTFakeNet;
import tagion.testbench.dart.dartinfo;

import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.dart.DART : DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : Archive, RecordFactory;

enum feature = Feature(
        "insert random stress test",
        [
        "This test uses dartfakenet to randomly add and remove archives in the same recorder."
]);

alias FeatureContext = Tuple!(
    AddRemoveAndReadTheResult, "AddRemoveAndReadTheResult",
    FeatureGroup*, "result"
);

@safe @Scenario("add remove and read the result",
    [])
class AddRemoveAndReadTheResult {

    DartInfo info;
    DART db1;
    RandomArchives[] random_archives;
    auto gen = Mt19937(1234);
    auto insert_watch = StopWatch(AutoStart.no);

    uint operations;


    this(DartInfo info) {
        this.info = info;
    }

    @Given("i have a dartfile")
    Document dartfile() {
        mkdirRecurse(info.module_path);
        // create the dartfile
        DART.create(info.dartfilename);

        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));
        return result_ok;
    }

    @Given("i have an array of randomarchives")
    Document randomarchives() {
    
        // first we generate the array of random archives
        auto seeds = gen.take(10);
        
        random_archives = gen.take(10).map!(s => RandomArchives(s)).array;

        return result_ok;
    }

    @When("i select n amount of elements in the randomarchives and add them to the dart and flip their bool. And count the number of instructions.")
    Document instructions() {


        foreach(i; 0..100) {
            writefln("running %s", i);
            auto rnd = MinstdRand0(gen.front);
            gen.popFront;
            auto sample_numbers = iota(random_archives.length).randomSample(3, rnd);

            auto recorder = db1.recorder();


            foreach(sample_number; sample_numbers) {
                auto docs = random_archives[sample_number].values.map!(a => DARTFakeNet.fake_doc(a));

                if (random_archives[sample_number].in_dart) {
                    recorder.insert(docs, Archive.Type.ADD);
                } else {
                    recorder.insert(docs, Archive.Type.REMOVE);
                }
                operations += docs.walkLength;

                random_archives[sample_number].in_dart = !random_archives[sample_number].in_dart;
            }
            insert_watch.start();
            db1.modify(recorder);
            insert_watch.stop();
        }

        return result_ok;
    }

    @Then("i read all the elements.")
    Document elements() {




        
        const long insert_time = insert_watch.peek.total!"msecs";

        writefln("number of operations %d, add and remove time: %d", operations, insert_time);
        writefln("ADD REMOVE pr. sec: %.1f", operations/double(insert_time)*1000);
        return result_ok;
    }

}
