module tagion.dart.DARTFakeNet;

import std.random;

//import tagion.gossip.InterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.basic.Types : Buffer, DARTIndex, Control;
import tagion.dart.DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONType : HiBONPrefix;
import tagion.hibon.HiBON : HiBON;

//import tagion.dart.DARTBasic;
import tagion.dart.Recorder;

import std.stdio;
import std.concurrency;

@safe
class DARTFakeNet : StdSecureNet {
    enum FAKE = "$fake#";
    this(string passphrase) {
        this();
        generateKeyPair(passphrase);
    }

    this() {
        import tagion.crypto.secp256k1.NativeSecp256k1;

        this._crypt = new NativeSecp256k1;

    }

    override immutable(Buffer) calcHash(scope const(ubyte[]) h) const {
        if (h.length is ulong.sizeof) {
            scope ubyte[] fake_h;
            fake_h.length = hashSize;
            fake_h[0 .. ulong.sizeof] = h;
            return fake_h.idup;
        }
        return super.rawCalcHash(h);
    }

    override immutable(Buffer) calcHash(
            scope const(ubyte[]) h1,
    scope const(ubyte[]) h2) const {
        scope ubyte[] fake_h1;
        scope ubyte[] fake_h2;
        if (h1.length is ulong.sizeof) {
            fake_h1.length = hashSize;
            fake_h1[0 .. ulong.sizeof] = h1;
        }
        else {
            fake_h1 = h1.dup;
        }
        if (h2.length is ulong.sizeof) {
            fake_h2.length = hashSize;
            fake_h2[0 .. ulong.sizeof] = h2;
        }
        else {
            fake_h2 = h2.dup;
        }
        return super.calcHash(fake_h1, fake_h2);
    }

    @trusted
    override immutable(Buffer) calcHash(const(Document) doc) const {
        import tagion.hibon.HiBONBase : Type;
        import std.exception : assumeUnique;

       if (doc.hasMember(FAKE) && (doc[FAKE].type is Type.UINT64)) {
            const x = doc[FAKE].get!ulong;
            import std.bitmanip : nativeToBigEndian;

            ubyte[] fingerprint;
            fingerprint.length = hashSize;
            fingerprint[0 .. ulong.sizeof] = nativeToBigEndian(x);
            return assumeUnique(fingerprint);
        }
        return super.calcHash(doc);
         //return rawCalcHash(doc.serialize);
    }


    @trusted
    override const(DARTIndex) _dartIndex(const(Document) doc) const {
        import tagion.hibon.HiBONBase : Type;
        import std.exception : assumeUnique;

       if (doc.hasMember(FAKE) && (doc[FAKE].type is Type.UINT64)) {
            const x = doc[FAKE].get!ulong;
            import std.bitmanip : nativeToBigEndian;

            ubyte[] fingerprint;
            fingerprint.length = hashSize;
            fingerprint[0 .. ulong.sizeof] = nativeToBigEndian(x);
            return DARTIndex(assumeUnique(fingerprint));
        }
        return super._dartIndex(doc);
    }

    static const(Document) fake_doc(const ulong x) {
        auto hibon = new HiBON;
        hibon[FAKE] = x;
        return Document(hibon);
    }
}
