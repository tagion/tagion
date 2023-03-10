module tagion.testbench.dart.dart_pseudo_random;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.path : setExtension, buildPath;
import std.file : mkdirRecurse;
import std.stdio;
import std.format : format;
import std.algorithm : map, filter, each, sort, equal;

import tagion.dart.DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.dart.DART : DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : Archive, RecordFactory;

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
        "Dart pseudo random test",
        ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
    AddPseudoRandomData, "AddPseudoRandomData",
    RemovePseudoRandomData, "RemovePseudoRandomData",
    FeatureGroup*, "result"
);

DARTIndex[] db1_fingerprints;
DARTIndex[] db2_fingerprints;

@safe @Scenario("Add pseudo random data.",
    [])
class AddPseudoRandomData {
    DART db1;
    DART db2;

    DartInfo info;

    this(DartInfo info) {
        this.info = info;
    }

    @Given("I have two dartfiles.")
    Document dartfiles() {
        // create the directory to store the DART in.
        mkdirRecurse(info.module_path);
        // create the dartfile
        DART.create(info.dartfilename);
        DART.create(info.dartfilename2);

        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));
        db2 = new DART(info.net, info.dartfilename2, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        return result_ok;
    }

    @Given("I have a pseudo random sequence of data stored in a table with a seed.")
    Document seed() {
        check(!info.states.empty, "Pseudo random sequence not generated");
        return result_ok;
    }

    @When("I randomly add all the data stored in the table to the two darts.")
    Document darts() {
        // shufflerandom seems to be modifying and saving the state. Research tommorow.

        // writefln("%s", typeof(info.states));

        db1_fingerprints = randomAdd(info.states, MinstdRand0(40), db1);

        db2_fingerprints = randomAdd(info.states, MinstdRand0(42), db2);


        return result_ok;        


    }

    @Then("the bullseyes of the two darts should be the same.")
    Document same() {

        check(db1.bullseye == db2.bullseye, "Bullseyes not the same");
        check(equal(db1_fingerprints.sort, db2_fingerprints.sort), "Fingerprints not the same");
        db1.close();
        db2.close();
        return result_ok;
    }

}

@safe @Scenario("Remove pseudo random data.",
    [])
class RemovePseudoRandomData {
    DART db1;
    DART db2;
    DartInfo info;
    DARTIndex[] remove_fingerprints;
    
    this(DartInfo info) {
        this.info = info;
    }
    @Given("two pseudo random darts and fingerprints")
    Document fingerprints() {
        Exception dart_exception;
        db1 = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));
        db2 = new DART(info.net, info.dartfilename2, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        // since the fingerprints of db1 and db2 should be the same, we can take the sample from db1.
        remove_fingerprints = db1_fingerprints.randomSample(db1_fingerprints.length/2, MinstdRand0(40)).array;
        return result_ok;
    }

    @When("i randomly go through n fingerprints and remove them from both darts.")
    Document darts() {
        randomRemove(remove_fingerprints, MinstdRand0(100), db1);
        randomRemove(remove_fingerprints, MinstdRand0(32), db2);

        return result_ok;
    }

    @Then("the bullseyes of the two darts should be the same.")
    Document same() {
        check(db1.bullseye == db2.bullseye, "Bullseyes not the same");


        db1.close();
        db2.close();
        return result_ok;
    }

}
