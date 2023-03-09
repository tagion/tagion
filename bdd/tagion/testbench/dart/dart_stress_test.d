module tagion.testbench.dart.dart_stress_test;
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
        "Dart pseudo random stress test",
        ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
    AddPseudoRandomData, "AddPseudoRandomData",
    FeatureGroup*, "result"
);

@safe @Scenario("Add pseudo random data.",
    [])
class AddPseudoRandomData {
    DART db1;

    DartInfo info;

    this(DartInfo info) {
        this.info = info;
    }

    @Given("I have one dartfile.")
    Document dartfile() {
        return Document();
    }

    @Given("I have a pseudo random sequence of data stored in a table with a seed.")
    Document seed() {
        return Document();
    }

    @When("I increasingly add more data in each recorder and time it.")
    Document it() {
        return Document();
    }

    @Then("the data should be read and checked.")
    Document checked() {
        return Document();
    }

}
