/// Basic fuinction and types used in the DART database
module tagion.dart.DARTBasic;

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

@safe
immutable(DARTIndex) dartIndex(const(HashNet) net, const(Document) doc) {
    if (!doc.empty && (doc.keys.front[0] is HiBONPrefix.HASH)) {
        if (doc.keys.front == STUB) {
            return doc[STUB].get!DARTIndex;
        }
        auto first = doc[].front;
        immutable value_data = first.data[first.dataPos .. first.dataPos + first.dataSize];
        return DARTIndex(net.rawCalcHash(value_data));
    }
    return DARTIndex(cast(Buffer) net.calcHash(doc));
}

/// Ditto
@safe
immutable(DARTIndex) dartIndex(T)(const(HashNet) net, T value) if (isHiBONRecord!T) {
    return net.dartIndex(value.toDoc);
}
