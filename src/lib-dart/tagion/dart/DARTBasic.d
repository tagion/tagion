/// Basic fuinction and types used in the DART database
module tagion.dart.DARTBasic;

@safe:
import std.typecons : Typedef;

import tagion.crypto.Types : BufferType, Fingerprint;
import tagion.basic.Types : Buffer;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.hibon.HiBONRecord : HiBONPrefix, STUB;
import std.format;

/**
* This is the raw-hash value of a message and is used when message is signed.
*/
alias DARTIndex = Typedef!(Buffer, null, BufferType.HASHPOINTER.stringof);

/**
 * Calculates the fingerprint used as an index for the DART
 * Handles the hashkey '#' and stub used in the DART
 * Params:
 *   net = Hash function interface
 *   doc = document to be hashed
 * Returns: 
 *   The DART fingerprint
 */

immutable(DARTIndex) dartIndex(const(HashNet) net, const(Document) doc) {
    if (!doc.empty && (doc.keys.front[0] is HiBONPrefix.HASH)) {
        if (doc.keys.front == STUB) {
            return doc[STUB].get!DARTIndex;
        }
        auto first = doc[].front;
        immutable value_data = first.data[0 .. first.size];
        return DARTIndex(net.rawCalcHash(value_data));
    }
    return DARTIndex(cast(Buffer) net.calcHash(doc));
}

/// Ditto
immutable(DARTIndex) dartIndex(T)(const(HashNet) net, T value) if (isHiBONRecord!T) {
    return net.dartIndex(value.toDoc);
}

unittest { // Check the #key hash with types
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.crypto.SecureInterfaceNet : HashNet;
    import tagion.hibon.HiBONRecord : label, HiBONRecord;

    const(HashNet) net = new StdHashNet;
    static struct HashU32 {
        @label("#key") uint x;
        string extra_name;
        mixin HiBONRecord;
    }

    static struct HashU64 {
        @label("#key") ulong x;
        mixin HiBONRecord;
    }

    HashU32 hash_u32;
    HashU64 hash_u64;
    hash_u32.x = 42;
    hash_u64.x = 42;
    import std.stdio;

    assert(net.dartIndex(hash_u32) != net.dartIndex(hash_u64));
    auto other_hash_u32 = hash_u32;
    other_hash_u32.extra_name = "extra";
    assert(net.dartIndex(hash_u32) == net.dartIndex(other_hash_u32),
            "Archives with the same #key should have the same dart-Index");
    assert(net.calcHash(hash_u32) != net.calcHash(other_hash_u32),
            "Two archives with same #key and different data should have different fingerprints");
}

immutable(Buffer) binaryHash(const(HashNet) net, scope const(ubyte[]) h1, scope const(ubyte[]) h2)
in {
    assert(h1.length is 0 || h1.length is net.hashSize,
            format("h1 is not a valid hash (length=%d should be 0 or %d", h1.length, net.hashSize));
    assert(h2.length is 0 || h2.length is net.hashSize,
            format("h2 is not a valid hash (length=%d should be 0 or %d", h2.length, net.hashSize));
}
out (result) {
    if (h1.length is 0) {
        assert(h2 == result);
    }
    else if (h2.length is 0) {
        assert(h1 == result);
    }
}
do {
    assert(h1.length is 0 || h1.length is net.hashSize,
            format("h1 is not a valid hash (length=%d should be 0 or %d", h1.length, net.hashSize));
    assert(h2.length is 0 || h2.length is net.hashSize,
            format("h2 is not a valid hash (length=%d should be 0 or %d", h2.length, net.hashSize));
    if (h1.length is 0) {
        return h2.idup;
    }
    if (h2.length is 0) {
        return h1.idup;
    }
    return net.rawCalcHash(h1 ~ h2);
}
