module tagion.testbench.dart.dart_two_archives_deep_rim;

import std.algorithm : filter, map;
import std.file : mkdirRecurse;
import std.format : format;
import std.path : buildPath, setExtension;
import std.range;
import std.stdio : writefln;
import std.typecons : Tuple;
import tagion.basic.Types : Buffer, mut;
import tagion.basic.basic : forceRemove;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART : DART;
import tagion.dart.DARTBasic : DARTIndex, binaryHash, dartIndex;
import tagion.dart.DARTFakeNet;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.DARTRim;
import tagion.dart.Recorder : Archive, RecordFactory;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONRecord;
import tagion.testbench.dart.dart_helper_functions : getFingerprints, getRead, getRim, goToSplit;
import tagion.testbench.dart.dartinfo;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "Dart two archives deep rim",
            ["All test in this bdd should use dart fakenet."]);

alias FeatureContext = Tuple!(
        AddOneArchive, "AddOneArchive",
        AddAnotherArchive, "AddAnotherArchive",
        RemoveArchive, "RemoveArchive",
        FeatureGroup*, "result"
);

Fingerprint[] fingerprints;
DARTIndex[] dart_indices;

@safe @Scenario("Add one archive.",
        ["mark #one_archive"])
class AddOneArchive {
    DART db;
    DARTIndex doc_dart_index;
    Fingerprint doc_fingerprint;
    Fingerprint bullseye;
    const DartInfo info;

    this(const DartInfo info) {
        this.info = info;
    }

    @Given("I have a dartfile.")
    Document dartfile() {
        // create the directory to store the DART in.
        mkdirRecurse(info.module_path);
        // create the dartfile
        info.dartfilename.forceRemove;
        DART.create(info.dartfilename, info.net);

        Exception dart_exception;
        db = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        return result_ok;
    }

    @Given("I add one archive1 in a sector.")
    Document sector() {
        auto recorder = db.recorder();
        const doc = DARTFakeNet.fake_doc(info.deep_table[0]);
        recorder.add(doc);
        pragma(msg, "fixme(cbr): Should this be Fingerprint or DARTIndex");
        doc_dart_index = recorder[].front.dart_index.mut;
        doc_fingerprint = recorder[].front.fingerprint.mut;
        bullseye = db.modify(recorder);
        return result_ok;
    }

    @Then("the archive should be read and checked.")
    Document checked() {
        check(doc_fingerprint == bullseye, "fingerprint and bullseyes not the same");
        fingerprints ~= doc_fingerprint;
        dart_indices ~= doc_dart_index;
        db.close();
        return result_ok;
    }

}

@safe @Scenario("Add another archive.",
        ["mark #two_archives"])
class AddAnotherArchive {
    DART db;

    DARTIndex doc_dart_index;
    Fingerprint doc_fingerprint;
    Fingerprint bullseye;
    const DartInfo info;

    this(const DartInfo info) {
        this.info = info;
    }

    @Given("#one_archive")
    Document onearchive() {
        Exception dart_exception;
        db = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        const bullseye = db.bullseye();
        const doc = DARTFakeNet.fake_doc(info.deep_table[0]);
        const doc_bullseye = dartIndex(info.net, doc);
        check(bullseye == doc_bullseye, "Bullseye not equal to doc");
        // db.dump;
        return result_ok;
    }

    @Given("i add another archive2 in the same sector, 5 rims deep as archive1.")
    Document archive1() {
        auto recorder = db.recorder();
        const doc = DARTFakeNet.fake_doc(info.deep_table[1]);
        recorder.add(doc);
        pragma(msg, "fixme(cbr): Should this be Fingerprint or DARTIndex");
        doc_dart_index = recorder[].front.dart_index.mut;
        doc_fingerprint = cast(Buffer) recorder[].front.fingerprint.mut;
        bullseye = db.modify(recorder);

        check(doc_fingerprint != bullseye, "Bullseye not updated");

        fingerprints ~= doc_fingerprint;
        dart_indices ~= doc_dart_index;
        // db.dump;
        return result_ok;
    }

    @Then("both archives should be read and checked.")
    Document checked() {
        const doc = getRead(dart_indices, info.hirpc, db);

        const recorder = db.recorder(doc);

        foreach (i, data; recorder[].enumerate) {
            const(ulong) archive = data.filed[info.FAKE].get!ulong;
            check(archive == info.deep_table[i], "Retrieved data not the same");
        }

        return result_ok;
    }

    @Then("check sector_A.")
    Document sectorA() {
        const doc = goToSplit(Rims.root, info.hirpc, db);
        const DARTIndex[] rim_fingerprints = getFingerprints(doc);

        const read_doc = getRead(rim_fingerprints, info.hirpc, db);
        const recorder = db.recorder(read_doc);
        foreach (i, data; recorder[].enumerate) {
            const(ulong) archive = data.filed[info.FAKE].get!ulong;
            check(archive == info.deep_table[i], "Retrieved data not the same");
        }

        return result_ok;
    }

    @Then("check the _bullseye.")
    Document _bullseye() {
        check(bullseye == info.net.binaryHash(fingerprints[0], fingerprints[1]),
                "Bullseye not equal to the hash of the two archives");
        db.close();
        return result_ok;
    }

}

@safe @Scenario("Remove archive",
        [])
class RemoveArchive {
    DART db;

    DARTIndex doc_fingerprint;
    Fingerprint bullseye;
    const DartInfo info;

    this(const DartInfo info) {
        this.info = info;
    }

    @Given("#two_archives")
    Document twoarchives() {
        Exception dart_exception;
        db = new DART(info.net, info.dartfilename, dart_exception);
        check(dart_exception is null, format("Failed to open DART %s", dart_exception.msg));

        return result_ok;
    }

    @Given("i remove archive1.")
    Document archive1() {
        auto recorder = db.recorder();
        recorder.remove(dart_indices[0]);
        bullseye = db.modify(recorder);
        // db.dump;
        return result_ok;
    }

    @Then("check that archive2 has been moved from the branch in sector A.")
    Document a() {

        const doc = goToSplit(Rims.root, info.hirpc, db);
        const DARTIndex[] rim_fingerprints = getFingerprints(doc, db);

        const read_doc = getRead(rim_fingerprints, info.hirpc, db);
        const recorder = db.recorder(read_doc);

        auto data = recorder[].front;
        const(ulong) archive = data.filed[info.FAKE].get!ulong;
        check(archive == info.deep_table[1], "Data is not correct");
        // db.dump;
        return result_ok;
    }

    @Then("check the _bullseye.")
    Document _bullseye() {
        check(bullseye == fingerprints[1], "Bullseye not updated correctly. Not equal to other element");
        db.close();
        return result_ok;
    }

}
