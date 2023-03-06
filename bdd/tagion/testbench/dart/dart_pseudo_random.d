module tagion.testbench.dart.dart_pseudo_random;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import std.path : setExtension, buildPath;
import std.file : mkdirRecurse;
import std.stdio;
import std.format : format;
import std.algorithm : map, filter, each;

import tagion.dart.DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.dart.DART : DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : Archive, RecordFactory;

import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.testbench.tools.Environment;
import tagion.actor.TaskWrapper;
import tagion.utils.Miscellaneous : toHexString;
import tagion.testbench.dart.dartinfo;

import tagion.communication.HiRPC;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.Keywords;
import std.range;
import tagion.utils.Random;

import tagion.hibon.HiBONRecord;

import tagion.testbench.dart.dart_helper_functions : getRim, getRead, goToSplit, getFingerprints;
import std.digest;

enum feature = Feature(
        "Dart pseudo random test",
        ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
    AddPseudoRandomData, "AddPseudoRandomData",
    FeatureGroup*, "result"
);

@safe @Scenario("Add pseudo random data.",
    [])


class AddPseudoRandomData {
    DART db1;
    DART db2;

    DartInfo info;

    DARTIndex[] db1_fingerprints;
    DARTIndex[] db2_fingerprints;

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
        import std.random;

        auto recorder1 = db1.recorder();

        auto rnd1 = MinstdRand0(42);

        foreach(state; info.states.randomShuffle(rnd1)) {
            const(Document[]) docs = state.list.map!(r => DARTFakeNet.fake_doc(r)).array;
            foreach(doc; docs) {
                recorder1.add(doc);
                db1_fingerprints ~= DARTIndex(recorder1[].front.fingerprint);
            }
            db1.modify(recorder1);
        }

        auto rnd2 = MinstdRand0(10);
        auto recorder2 = db2.recorder();

        foreach(state; info.states.randomShuffle(rnd2)) {
            const(Document[]) docs = state.list.map!(r => DARTFakeNet.fake_doc(r)).array;
            foreach(doc; docs) {
                recorder2.add(doc);
                db2_fingerprints ~= DARTIndex(recorder2[].front.fingerprint);
            }
            db2.modify(recorder2);
        }

        return result_ok;        


    }

    @Then("the bullseyes of the two darts should be the same.")
    Document same() {


        // check that data is the same
        writefln("db1: %s", db1_fingerprints.map!(f => f.toHexString));
        writefln("db2: %s", db2_fingerprints.map!(f => f.toHexString));
        check(db1.bullseye == db2.bullseye, "Bullseyes not the same");



        db1.close();
        db2.close();
        return Document();
    }

}
