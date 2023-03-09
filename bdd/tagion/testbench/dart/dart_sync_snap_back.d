module tagion.testbench.dart.dart_sync_snap_back;
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

enum feature = Feature(
        "Dart snap syncing",
        [
        "All test in this bdd should use dart fakenet. This test covers after a archive has been removed that was in a deep rim. What then happens when syncing such a branch?"
]);

alias FeatureContext = Tuple!(
    SyncToAnotherDb, "SyncToAnotherDb",
    FeatureGroup*, "result"
);

@safe @Scenario("Sync to another db.",
    [])
class SyncToAnotherDb {
    DART db1;
    DART db2;

    DARTIndex[] db1_fingerprints;

    const ushort angle = 0;
    const ushort size = 10;

    DartInfo info;

    this(DartInfo info) {
        this.info = info;
    }
    @Given("I have a dartfile with one archive.")
    Document archive() {
        writefln("wowo");
        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception); 
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        const bullseye = db1.bullseye();

        const doc = DARTFakeNet.fake_doc(info.deep_table[1]);
        const doc_bullseye = dartIndex(info.net, doc);


        check(bullseye == doc_bullseye, "Bullseye not equal to doc");

        return result_ok;
    }

    @Given("I have a empty dartfile2.")
    Document dartfile2() {
        writefln("%s", info.dartfilename2);
        DART.create(info.dartfilename2);
        Exception dart_exception;
        db2 = new DART(info.net, info.dartfilename2, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        return result_ok;
    }

    @Given("I sync the databases.")
    Document databases() {
        syncDarts(db1, db2, angle, size);
        return result_ok;
    }

    @Then("the bullseyes should be the same.")
    Document same() {
        check(db1.bullseye == db2.bullseye, "Bullseyes not the same");
        return result_ok;
    }

    @Then("check if the data is not lost.")
    Document lost() {

        db1.close();
        db2.close();
        return Document();
    }

}
