/// Helper functions for interfacing with the DART. 
module tagion.testbench.dart.dart_helper_functions;

import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.dart.DART : DART;
import tagion.Keywords;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.dart.DARTFile : DARTFile;
import std.range;
import std.algorithm : map, filter;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.dart.Recorder : RecordFactory, Archive;
import tagion.dart.DARTcrud : dartRead, dartRim;



import std.stdio : writefln;

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
    writefln("running with %s", rim);
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

    if (RecordFactory.Recorder.isRecord(doc)) {
        assert(db !is null, "DART needed for this use case");
        auto recorder = db.recorder(doc);
        return recorder[].map!(a => DARTIndex(a.fingerprint)).array;
    }

    return DARTFile.Branches(doc).fingerprints
        .filter!(f => !f.empty)
        .map!(f => DARTIndex(f))
        .array;
}

