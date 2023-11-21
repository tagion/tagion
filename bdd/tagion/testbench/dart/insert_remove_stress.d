module tagion.testbench.dart.insert_remove_stress;
// Default import list for bdd
import std.algorithm;
import std.datetime.stopwatch;
import std.file : mkdirRecurse;
import std.format;
import std.random;
import std.range;
import std.stdio;
import std.typecons : Tuple;
import tagion.basic.Types : Buffer;
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.testbench.tools.Environment;

// dart
import std.digest;
import tagion.basic.basic : forceRemove;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.dart.DART : DART;
import tagion.dart.DARTBasic;
import tagion.dart.DARTFakeNet;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : Archive, RecordFactory;
import tagion.testbench.dart.dart_helper_functions;
import tagion.testbench.dart.dartinfo;

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
    Mt19937 gen;
    auto insert_watch = StopWatch(AutoStart.no);
    auto read_watch = StopWatch(AutoStart.no);
    uint number_of_seeds;
    uint number_of_rounds;
    uint number_of_samples;

    uint operations;

    this(DartInfo info, const uint seed, const uint number_of_seeds, const uint number_of_rounds, const uint number_of_samples) {
        check(number_of_samples < number_of_seeds, "number of samples must be smaller than number of seeds");
        this.info = info;
        gen = Mt19937(seed);
        this.number_of_rounds = number_of_rounds;
        this.number_of_samples = number_of_samples;
        this.number_of_seeds = number_of_seeds;
    }

    @Given("i have a dartfile")
    Document dartfile() {
        mkdirRecurse(info.module_path);
        // create the dartfile
        info.dartfilename.forceRemove;
        DART.create(info.dartfilename, info.net);

        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));
        return result_ok;
    }

    @Given("i have an array of randomarchives")
    Document randomarchives() {

        // first we generate the array of random archives

        random_archives = gen.take(number_of_seeds).map!(s => RandomArchives(s)).array;

        return result_ok;
    }

    @When("i select n amount of elements in the randomarchives and add them to the dart and flip their bool. And count the number of instructions.")
    Document instructions() {

        foreach (i; 0 .. number_of_rounds) {
            writefln("running %s", i);
            auto rnd = MinstdRand0(gen.front);
            gen.popFront;
            auto sample_numbers = iota(random_archives.length).randomSample(number_of_samples, rnd).array;
            auto recorder = db1.recorder();

            foreach (sample_number; sample_numbers) {
                auto docs = random_archives[sample_number].values.map!(a => DARTFakeNet.fake_doc(a));

                if (!random_archives[sample_number].in_dart) {
                    recorder.insert(docs, Archive.Type.ADD);
                }
                else {

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

        auto fingerprints = random_archives
            .filter!(s => s.in_dart == true)
            .map!(d => d.values)
            .join
            .map!(a => DARTFakeNet.fake_doc(a))
            .map!(a => info.net.dartIndex(a))
            .array;

        writefln("###");
        read_watch.start();
        auto read_recorder = db1.loads(fingerprints, Archive.Type.NONE);
        read_watch.stop();
        writeln(read_recorder[].walkLength);

        check(read_recorder[].walkLength == fingerprints.length, "the length of the read archives is not the same as the expected");

        auto expected_read_docs = random_archives
            .filter!(s => s.in_dart == true)
            .map!(d => d.values)
            .join
            .map!(a => DARTFakeNet.fake_doc(a))
            .array;

        auto expected_recorder = db1.recorder();
        expected_recorder.insert(expected_read_docs);

        check(equal(expected_recorder[].map!(a => a.filed), read_recorder[].map!(a => a.filed)), "data not the same");

        const long insert_time = insert_watch.peek.total!"msecs";
        const long read_time = read_watch.peek.total!"msecs";

        writefln("Total number of operations: %d", operations + fingerprints.length);
        writefln("ADD and REMOVE operations: %d. pr. sec: %s", operations, operations / double(insert_time) * 1000);
        writefln("READ operations: %s. pr.sec %s", fingerprints.length, fingerprints.length / double(read_time) * 1000);

        // the total time
        writefln("Total operations pr. sec: %1.f", (operations + fingerprints.length) / double(insert_time + read_time) * 1000);
        db1.close;
        return result_ok;
    }

}
