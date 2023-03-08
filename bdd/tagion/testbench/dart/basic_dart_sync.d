module tagion.testbench.dart.basic_dart_sync;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.path : setExtension, buildPath;
import std.file : mkdirRecurse;
import std.stdio;
import std.format : format;
import std.algorithm : map, filter, each, sort, equal;
import tagion.basic.Basic : tempfile;

import tagion.dart.DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.dart.DART : DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : Archive, RecordFactory;
import tagion.testbench.tools.Environment;
import tagion.dart.BlockFile : BlockFile;

import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.testbench.tools.Environment;
import tagion.utils.Miscellaneous : toHexString;
import tagion.testbench.dart.dartinfo;

import tagion.communication.HiRPC;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.Keywords;
import std.range;
import tagion.utils.Random;
import std.random : randomShuffle, MinstdRand0, randomSample;


import tagion.hibon.HiBONRecord;

import tagion.testbench.dart.dart_helper_functions;
import std.digest;

enum feature = Feature(
        "DARTSynchronization",
        ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
    FullSync, "FullSync",
    PartialSync, "PartialSync",
    FeatureGroup*, "result"
);

@safe @Scenario("Full sync.",
    [])
class FullSync {
    DART db1;
    DART db2;

    DARTIndex[] db1_fingerprints;
    string[] journal_filenames;

    const ushort angle = 0;
    const ushort size = 10;

    DartInfo info;

    this(DartInfo info) {
        this.info = info;
    }

    @Given("I have a dartfile1 with pseudo random data.")
    Document randomData() {
        check(!info.states.empty, "Pseudo random sequence not generated");

        mkdirRecurse(info.module_path);
        // create the dartfile
        DART.create(info.dartfilename);

        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        auto sector_states = info.states
                                .map!(state => state.list
                                    .map!(archive => putInSector(archive, angle, size))).array;
        
        db1_fingerprints = randomAdd(sector_states, MinstdRand0(65), db1);
        
        return result_ok;
    }

    @Given("I have a empty dartfile2.")
    Document emptyDartfile2() {
        DART.create(info.dartfilename2);
        
        Exception dart_exception;
        db2 = new DART(info.net, info.dartfilename2, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));


        return result_ok;
    }

    @Given("I synchronize dartfile1 with dartfile2.")
    Document withDartfile2() {


        enum TEST_BLOCK_SIZE = 0x80;

        foreach (sector; DART.SectorRange(angle, size)) {
            writefln("running sector %04x", sector);
            immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
            journal_filenames ~= journal_filename;
            BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
            auto synch = new TestSynchronizer(journal_filename, db2, db1);

            auto db2_synchronizer = db2.synchronizer(synch, DART.Rims(sector));
            // D!(sector, "%x");
            while (!db2_synchronizer.empty) {
                (() @trusted => db2_synchronizer.call)();
            }
        }
        foreach (journal_filename; journal_filenames) {
            db2.replay(journal_filename);
        }
        
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

@safe @Scenario("Partial sync.",
    [])
class PartialSync {

    @Given("I have a dartfile1 with pseudo random data.")
    Document randomData() {
        return Document();
    }

    @Given("I have added some of the pseudo random data to dartfile2.")
    Document toDartfile2() {
        return Document();
    }

    @Given("I synchronize dartfile1 with dartfile2.")
    Document withDartfile2() {
        return Document();
    }

    @Then("the bullseyes should be the same.")
    Document theSame() {
        return Document();
    }

}
