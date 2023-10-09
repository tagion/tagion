/// Helper functions for interfacing with the DART. 
module tagion.testbench.dart.dart_helper_functions;

import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.dart.DART : DART;
import tagion.Keywords;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.dart.DARTFile : DARTFile;
import tagion.basic.basic : isinit;
import std.range;
import std.algorithm : map, filter;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.dart.Recorder : RecordFactory, Archive;
import tagion.dart.DARTcrud : dartRead, dartRim;
import std.random : randomShuffle, MinstdRand0;
import tagion.utils.Random;
import tagion.dart.DARTFakeNet;
import std.algorithm : each;
import tagion.basic.basic : tempfile;
import tagion.utils.Miscellaneous : toHexString;
import std.stdio : writefln, writeln;
import std.format;
import tagion.dart.BlockFile : BlockFile;

/** 
 * Takes a Rim and returns the document.
 * Params:
 *   rim = The rim to check
 *   hirpc = The hirpc used
 *   db = The dart 
 * Returns: Result Document with branches and or records.
 */
Document getRim(DART.Rims rim, HiRPC hirpc, DART db) @safe {
    const rim_sender = dartRim(rim, hirpc);
    auto rim_receiver = hirpc.receive(rim_sender.toDoc);
    auto rim_result = db(rim_receiver, false);
    return rim_result.message[Keywords.result].get!Document;
}

/** 
 * Reads a list of DARTIndexes and returnts the document
 * Params:
 *   fingerprints = list of fingerprints to read
 *   hirpc = the hirpc used
 *   db = The dart
 * Returns: Result Document.
 */
Document getRead(const DARTIndex[] fingerprints, HiRPC hirpc, DART db) @safe {
    const sender = dartRead(fingerprints, hirpc);
    auto receiver = hirpc.receive(sender.toDoc);
    auto result = db(receiver, false);
    return result.message[Keywords.result].get!Document;
}

/** 
 * Traverses dart until a split occurs.
 * Params:
 *   rim = 
 *   hirpc = 
 *   db = 
 * Returns: Document with split, or the last document able to be retrieved if no splits.
 */
Document goToSplit(const DART.Rims rim, const HiRPC hirpc, DART db) @safe {
    const rim_doc = getRim(rim, hirpc, db);

    if (DARTFile.Branches.isRecord(rim_doc)) {
        auto rim_fingerprints = DARTFile.Branches(rim_doc)
            .fingerprints
            .enumerate
            .filter!(f => !f.value.empty)
            .array;

        if (rim_fingerprints.length > 1) {
            return rim_doc;
        }
        return goToSplit(DART.Rims(rim, rim_fingerprints.front.index), hirpc, db);
    }

    return rim_doc;
}

/** 
 * Helper method to retrieve fingerprints from a Document
 * Params:
 *   doc = The Document with fingerprints
 *   db = 
 * Returns: Returns a list of fingerprints from a Document
 */
DARTIndex[] getFingerprints(const Document doc, DART db = null) @safe {

    pragma(msg, "fixme(cbr): Check the that we use the dartIndex and Fingerprint in this test correctetly");
    if (RecordFactory.Recorder.isRecord(doc)) {
        assert(db !is null, "DART needed for this use case");
        auto recorder = db.recorder(doc);
        return recorder[].map!(a => cast(DARTIndex)(a._fingerprint)).array;

    }

    return DARTFile.Branches(doc).dart_indices
        .filter!(f => !f.isinit)
        .array;
}

/** 
 * Adds archive in a shuffled random order based on the sequence states.
 * Params:
 *   states = the random sequence.
 *   rnd = seed for random number generator.
 *   db = The dart
 * Returns: list of fingerprints added to the db.
 */

DARTIndex[] randomAdd(const Sequence!ulong[] states, MinstdRand0 rnd, DART db) @safe {
    DARTIndex[] dart_indexs;

    foreach (state; states.dup.randomShuffle(rnd)) {
        auto recorder = db.recorder();

        const(Document[]) docs = state.list.map!(r => DARTFakeNet.fake_doc(r)).array;
        foreach (doc; docs) {
            recorder.add(doc);
            dart_indexs ~= DARTIndex(recorder[].front.dart_index);
        }
        db.modify(recorder);
    }
    return dart_indexs;
}

DARTIndex[] randomAdd(T)(T ranges, MinstdRand0 rnd, DART db) @safe
        if (isRandomAccessRange!T && isInputRange!(ElementType!T) && is(
            ElementType!(ElementType!T) : const(ulong))) {
    DARTIndex[] dart_indexs;
    foreach (range; ranges.randomShuffle(rnd)) {
        auto recorder = db.recorder();
        auto docs = range.map!(r => DARTFakeNet.fake_doc(r));
        foreach (doc; docs) {
            recorder.add(doc);
            dart_indexs ~= DARTIndex(recorder[].front.dart_index);
        }
        db.modify(recorder);
    }
    return dart_indexs;
}

/** 
 * Removes archive in a random order.
 * Params:
 *   dart_indexs = The dart_indexs to remove
 *   rnd = the random seed
 *   db = the database
 */
void randomRemove(const DARTIndex[] dart_indexs, MinstdRand0 rnd, DART db) @safe {
    auto recorder = db.recorder();

    const random_order_dart_indexs = dart_indexs.dup.randomShuffle(rnd);
    foreach (dart_index; random_order_dart_indexs) {
        writefln("removing %s", dart_index.toHexString);
        recorder.remove(dart_index);
    }
    db.modify(recorder);
}

/** 
 * Changes the sector in which the archive is created in. This is for testing only an angle of the database. 
 * Params:
 *   archive = the archive to change
 *   angle = The angle / sector 
 *   size = The size from the angle so that it is possible to have more than one.
 * Returns: new ulong where the sector has been changed.
 */
ulong putInSector(ulong archive, const ushort angle, const ushort size) @safe {

    enum size_none_sector = (ulong.sizeof - ushort.sizeof) * 8;
    const ulong sector = ((archive >> size_none_sector - angle) % size + angle) << size_none_sector;

    const(ulong) new_archive = archive & ~(
            ulong(ushort.max) << size_none_sector) | ulong(sector) << size_none_sector;

    return new_archive;
}

// same as in unittests.
import tagion.dart.synchronizer;

static class TestSynchronizer : JournalSynchronizer {
    protected DART foreign_dart;
    protected DART owner;
    this(string journal_filename, DART owner, DART foreign_dart) @safe {
        this.foreign_dart = foreign_dart;
        this.owner = owner;
        auto _journalfile = BlockFile(journal_filename);
        super(_journalfile);
    }

    //
    // This function emulates the connection between two DART's
    // in a single thread
    //
    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request) {
        Document send_request_to_foreign_dart(const Document foreign_doc) {
            //
            // Remote excution
            // Receive on the foreign end
            const foreign_receiver = foreign_dart.hirpc.receive(foreign_doc);
            // Make query in to the foreign DART
            const foreign_response = foreign_dart(foreign_receiver);

            return foreign_response.toDoc;
        }

        immutable foreign_doc = request.toDoc;
        (() @trusted { fiber.yield; })();
        // Here a yield loop should be implement to poll for response from the foriegn DART
        // A timeout should also be implemented in this poll loop
        const response_doc = send_request_to_foreign_dart(foreign_doc);
        //
        // Process the response returned for the foreign DART
        //
        const received = owner.hirpc.receive(response_doc);
        return received;
    }
}

/** 
 * Syncs to darts
 * Params:
 *   db1 = Dart to sync From
 *   db2 = Dart to sync TO
 *   from = angle start
 *   to = angle end
 */
void syncDarts(DART db1, DART db2, const ushort from, const ushort to) @safe {

    enum TEST_BLOCK_SIZE = 0x80;
    string[] journal_filenames;

    foreach (sector; DART.SectorRange(from, to)) {
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

}

struct RandomArchives {
    import std.random;
    import std.random : Random;

    uint seed;
    bool in_dart;
    uint number_of_archives;

    this(const uint _seed, const uint from = 1, const uint to = 10) pure const @safe {
        seed = _seed;
        auto rnd = Random(seed);
        number_of_archives = uniform(from, to, rnd);
    }

    auto values() pure nothrow @nogc @safe {
        auto gen = Mt19937_64(seed);
        return gen.take(number_of_archives);
    }
}

unittest {
    import std.stdio;
    import std.algorithm;

    const seed = 12345UL;
    auto r = RandomArchives(seed, 1, 10);
    auto t = RandomArchives(seed, 1, 10);

    assert(r.values == t.values);
}
