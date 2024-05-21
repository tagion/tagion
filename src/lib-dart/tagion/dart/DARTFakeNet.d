module tagion.dart.DARTFakeNet;

import std.typecons : Typedef;

import tagion.basic.Types : Buffer;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types : BufferType, Fingerprint;
import tagion.dart.DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : HiBONPrefix;

/**
* This is the raw-hash value of a message and is used when message is signed.
*/
alias DARTIndex = Typedef!(Buffer, null, BufferType.HASHPOINTER.stringof);

@safe
class DARTFakeNet : StdSecureNet {
    enum FAKE = "$fake#";
    this(string passphrase) {
        this();
        generateKeyPair(passphrase);
    }

    this() {
        super();

    }

    override Fingerprint calcHash(scope const(ubyte[]) h) const {
        if (h.length is ulong.sizeof) {
            scope ubyte[] fake_h;
            fake_h.length = hashSize;
            fake_h[0 .. ulong.sizeof] = h;
            return Fingerprint(fake_h.idup);
        }
        return Fingerprint(super.rawCalcHash(h));
    }

    @trusted
    override Fingerprint calcHash(const(Document) doc) const {
        import std.exception : assumeUnique;
        import tagion.hibon.HiBONBase : Type;

        if (doc.hasMember(FAKE) && (doc[FAKE].type is Type.UINT64)) {
            const x = doc[FAKE].get!ulong;
            import std.bitmanip : nativeToBigEndian;

            ubyte[] fingerprint;
            fingerprint.length = hashSize;
            fingerprint[0 .. ulong.sizeof] = nativeToBigEndian(x);
            return Fingerprint(assumeUnique(fingerprint));
        }
        return super.calcHash(doc);
        //return rawCalcHash(doc.serialize);
    }

    static const(Document) fake_doc(const ulong x) {
        auto hibon = new HiBON;
        hibon[FAKE] = x;
        return Document(hibon);
    }

    enum hashname = "fake256";
    override string multihash() const pure nothrow @nogc {
        return hashname;
    }
}
