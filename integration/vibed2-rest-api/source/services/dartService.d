module services.dartService;

import std.algorithm : map;
import std.array;

import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.dart.DARTFakeNet;
import tagion.hibon.Document;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;


struct DartService {
    SecureNet net;
    DART db;

    this(const(string) dart_filename, const(string) password) {
        net = new StdSecureNet();
        net.generateKeyPair(password);
        // net = new DARTFakeNet;


        db = new DART(net, dart_filename);
    }

    ~this() {
        db.close;
    }

    const(DARTIndex) modify(const(Document) doc) {
        auto recorder = db.recorder();
        recorder.add(doc);
        const fingerprint = recorder[].front.fingerprint;
        db.modify(recorder);
        return fingerprint;
    }

    const(Document)[] read(const(DARTIndex)[] fingerprints) {
        auto read_recorder = db.loads(fingerprints);

        auto docs = read_recorder[].map!(a => a.filed).array;
        return docs;
    }

    void remove(const(DARTIndex)[] fingerprints) {
        auto recorder = db.recorder();
        foreach(fingerprint; fingerprints) {
            recorder.remove(fingerprint);
        }
        db.modify(recorder);
    }

    const(DARTIndex) bullseye() {
        return DARTIndex(db.bullseye);
    }
}



