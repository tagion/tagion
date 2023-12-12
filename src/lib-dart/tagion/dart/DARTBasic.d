/// Basic fuinction and types used in the DART database
module tagion.dart.DARTBasic;

@safe:
import std.format;
import std.traits;
import std.typecons : Typedef;
import tagion.basic.Types : Buffer;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.Types : BufferType, Fingerprint;
import tagion.dart.DARTFile : KEY_SPAN;
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
    import tagion.crypto.SecureInterfaceNet : HashNet;
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.hibon.HiBONRecord : HiBONRecord, label;

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

DARTIndex dartKey(T)(const(HashNet) net, const(char[]) name, T val) {
    import std.stdio;
    import tagion.hibon.HiBON;

    const key = (name[0] == HiBONPrefix.HASH) ? name.idup : (HiBONPrefix.HASH ~ name).idup;
    auto h = new HiBON;
    h[key] = val;
    return net.dartIndex(Document(h));
}

unittest {
    import std.format;
    import std.traits;
    import std.typecons;
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.hibon.BigNumber;
    import tagion.hibon.HiBONBase : Type;
    import tagion.hibon.HiBONRecord : HiBONRecord, label;
    import tagion.utils.StdTime;

    const net = new StdHashNet;

    static struct DARTKey(T) {
        @label("#key") T key;
        int x;

        mixin HiBONRecord!(q{
            this(T key, int x) {
                this.key=key;
                this.x=x;
            }
        });
    }

    auto dartKeyT(T)(T key, int x) {
        return DARTKey!T(key, x);
    }

    alias Table = Tuple!(
            BigNumber, Type.BIGINT.stringof,
            bool, Type.BOOLEAN.stringof,
            float, Type.FLOAT32.stringof,
            double, Type.FLOAT64.stringof,
            int, Type.INT32.stringof,
            long, Type.INT64.stringof,
            sdt_t, Type.TIME.stringof,
            uint, Type.UINT32.stringof,
            ulong, Type.UINT64.stringof,
            immutable(ubyte)[], Type.BINARY.stringof,
            string, Type.STRING.stringof,

    );
    // dfmt on

    Table test_table;
    test_table.FLOAT32 = 1.23;
    test_table.FLOAT64 = 1.23e200;
    test_table.INT32 = -42;
    test_table.INT64 = -0x0123_3456_789A_BCDF;
    test_table.UINT32 = 42;
    test_table.UINT64 = 0x0123_3456_789A_BCDF;
    test_table.BIGINT = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");
    test_table.BOOLEAN = true;
    test_table.TIME = 1001;
    test_table.BINARY = [1, 2, 3];
    test_table.STRING = "Text";
    import std.stdio;

    foreach (i, t; test_table) {
        const dart_index = net.dartKey("#key", t);
        const dart_key = dartKeyT(t, 42);
        assert(dart_index == net.dartIndex(dart_key), format("%s dartKey failed", Fields!Table[i].stringof));
        assert(dart_index != net.calcHash(dart_key.toDoc), format("%s dart_index should not be equal to the fingerpint", Fields!Table[i]
            .stringof));
    }
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

Fingerprint binaryHash(const(HashNet) net, scope const(Fingerprint) h1, scope const(Fingerprint) h2) {
    return Fingerprint(binaryHash(net, cast(Buffer) h1, cast(Buffer) h2));
}
/**

 * Calculates the sparsed Merkle root from the branch-table list
* The size of the table must be KEY_SPAN
* Leaves in the branch table which doen't exist should have the value null
 * Params:
 *   net = The hash object/function used to calculate the hashs
 *   table = List if hash-value(fingerprint) in the branch
 * Returns: 
 *  The Merkle root
 */
Buffer sparsed_merkletree(const HashNet net, const(Buffer[]) table)
    in(table.length == KEY_SPAN)
do {
    immutable(Buffer) merkletree(
            const(Buffer[]) left,
    const(Buffer[]) right) {
        Buffer _left_fingerprint;
        Buffer _right_fingerprint;
        if ((left.length == 1) && (right.length == 1)) {
            _left_fingerprint = left[0];
            _right_fingerprint = right[0];
        }
        else {
            immutable left_mid = left.length >> 1;
            immutable right_mid = right.length >> 1;
            _left_fingerprint = merkletree(left[0 .. left_mid], left[left_mid .. $]);
            _right_fingerprint = merkletree(right[0 .. right_mid], right[right_mid .. $]);
        }
        if (_left_fingerprint is null) {
            return _right_fingerprint;
        }
        else if (_right_fingerprint is null) {
            return _left_fingerprint;
        }
        else {
            return net.binaryHash(_left_fingerprint, _right_fingerprint);
        }
    }

    immutable mid = table.length >> 1;
    return merkletree(table[0 .. mid], table[mid .. $]);
}

Fingerprint sparsed_merkletree(const HashNet net, const(Fingerprint[]) table) @trusted {
    return Fingerprint(sparsed_merkletree(net, cast(const(Buffer[])) table));
}

unittest { // StdHashNet
    //import tagion.utils.Miscellaneous : toHex=toHexString;
    import core.exception : AssertError;
    import std.exception : assertThrown;
    import std.string : representation;
    import tagion.hibon.HiBONRecord : hasHashKey, isStub;

    // import std.stdio;

    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.hibon.HiBON;

    const net = new StdHashNet;
    Document doc; // This is the data which is filed in the DART
    {
        auto hibon = new HiBON;
        hibon["text"] = "Some text";
        doc = Document(hibon);
    }

    immutable doc_fingerprint = net.rawCalcHash(doc.serialize);

    {
        assert(net.binaryHash(null, null).length is 0);
        assert(net.binaryHash(doc_fingerprint, null) == doc_fingerprint);
        assert(net.binaryHash(null, doc_fingerprint) == doc_fingerprint);
    }

}
