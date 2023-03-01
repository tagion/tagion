module tagion.testbench.dart.dart_helper_functions;

import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.dart.DART : DART;
import tagion.Keywords;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.dart.DARTFile : DARTFile;
import std.range;
import std.algorithm : map, filter;

Document getRim(DART.Rims rim, HiRPC hirpc, DART db) @safe {
    const rim_sender = DART.dartRim(rim, hirpc);
    auto rim_receiver = hirpc.receive(rim_sender.toDoc);
    auto rim_result = db(rim_receiver, false);
    return rim_result.message[Keywords.result].get!Document;
}

Document getRead(DARTIndex[] fingerprints, HiRPC hirpc, DART db) @safe {
    const sender = DART.dartRead(fingerprints, hirpc);
    auto receiver = hirpc.receive(sender.toDoc);
    auto result = db(receiver, false);
    return result.message[Keywords.result].get!Document;
}

Document goToSplit(const DART.Rims rim, const HiRPC hirpc, DART db) @safe {
    const rim_doc = getRim(rim, hirpc, db);

    if (!DARTFile.Branches.isRecord(rim_doc)) {
        return rim_doc;
    }

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

DARTIndex[] getFingerprints(const Document doc) @safe {
    return DARTFile.Branches(doc).fingerprints
        .filter!(f => !f.empty)
        .map!(f => DARTIndex(f))
        .array;
}
