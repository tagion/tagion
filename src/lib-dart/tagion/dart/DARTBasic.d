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

    writefln("dart_index=%(%02x%)", net.dartIndex(hash_u32));
    writefln("dart_index=%(%02x%)", net.dartIndex(hash_u64));
    assert(net.dartIndex(hash_u32) != net.dartIndex(hash_u64));
    auto other_hash_u32 = hash_u32;
    other_hash_u32.extra_name = "extra";
    writefln("dart_index=%(%02x%)", net.dartIndex(other_hash_u32));
    assert(net.dartIndex(hash_u32) == net.dartIndex(other_hash_u32), "Archives with the same #key should have the same dart-Index");
    writefln("fingerprint=%(%02x%)", net.calcHash(other_hash_u32));
    writefln("fingerprint=%(%02x%)", net.calcHash(hash_u32));
    assert(net.calcHash(hash_u32) != net.calcHash(other_hash_u32), "Two archives with same #key and different data should have different fingerprints");
}
