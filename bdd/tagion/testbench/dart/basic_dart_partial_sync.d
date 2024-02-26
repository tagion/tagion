module tagion.testbench.dart.basic_dart_partial_sync;
// Default import list for bdd
import std.algorithm : each, equal, filter, map, sort;
import std.file : mkdirRecurse;
import std.format : format;
import std.path : buildPath, setExtension;
import std.random : MinstdRand0, randomSample, randomShuffle;
import std.range;
import std.stdio;
import std.typecons : Tuple;
import tagion.Keywords;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.dart.BlockFile : BlockFile;
import tagion.dart.DART : DART;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.dart.DARTFakeNet;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : Archive, RecordFactory;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONRecord;
import tagion.testbench.dart.dart_helper_functions;
import tagion.testbench.dart.dartinfo;
import tagion.testbench.tools.Environment;
import tagion.utils.Random;

enum feature = Feature(
            "DARTSynchronization partial sync.",
            ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
        PartialSync, "PartialSync",
        FeatureGroup*, "result"
);

@safe @Scenario("Partial sync.",
        [])
class PartialSync {
    DART db1;
    DART db2;

    DARTIndex[] db1_fingerprints;
    DARTIndex[] db2_fingerprints;

    const ushort angle = 0;
    const ushort size = 10;

    ulong[][] sector_states;

    DartInfo info;

    this(DartInfo info) {
        this.info = info;
    }

    @Given("I have a dartfile1 with pseudo random data.")
    Document randomData() {
        check(!info.states.empty, "Pseudo random sequence not generated");

        mkdirRecurse(info.module_path);
        // create the dartfile
        DART.create(info.dartfilename, info.net);

        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        sector_states = info.states
            .map!(state => state.list
                    .map!(archive => putInSector(archive, angle, size)).array).array;

        db1_fingerprints = randomAdd(sector_states, MinstdRand0(65), db1);

        return result_ok;
    }

    @Given("I have added some of the pseudo random data to dartfile2.")
    Document toDartfile2() {
        DART.create(info.dartfilename2, info.net);

        Exception dart_exception;
        db2 = new DART(info.net, info.dartfilename2, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        auto partial_sector_states = sector_states.randomSample(sector_states.length / 2, MinstdRand0(423)).array;

        db2_fingerprints = randomAdd(partial_sector_states, MinstdRand0(314), db2);

        check(db1.bullseye != db2.bullseye, "Bullseyes should not be the same");

        return result_ok;
    }

    @Given("I synchronize dartfile1 with dartfile2.")
    Document withDartfile2() {
        syncDarts(db1, db2, angle, size);
        return result_ok;
    }

    @Then("the bullseyes should be the same.")
    Document theSame() {
        check(db1.bullseye == db2.bullseye, "Bullseyes not the same");

        db1.close();
        db2.close();
        return result_ok;
    }

}
