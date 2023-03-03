module tagion.dart.DARTBasic;

import std.typecons : Typedef;

import tagion.basic.Types : Buffer, BufferType;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONType : isHiBONType;
import tagion.hibon.HiBONType : HiBONPrefix, STUB;

/**
* This is the raw-hash value of a message and is used when message is signed.
*/
alias DARTIndex = Typedef!(Buffer, null, BufferType.HASHPOINTER.stringof);

@safe
const(DARTIndex) dartIndex(const(HashNet) net, const(Document) doc) {
    if (!doc.empty && (doc.keys.front[0] is HiBONPrefix.HASH)) {
        if (doc.keys.front == STUB) {
            return doc[STUB].get!DARTIndex;
        }
        auto first = doc[].front;
        immutable value_data = first.data[first.dataPos .. first.dataPos + first.dataSize];
        return DARTIndex(net.rawCalcHash(value_data));
    }
    return DARTIndex(net.rawCalcHash(doc.serialize));
}

@safe
const(DARTIndex) dartIndex(T)(const(HashNet) net, T value) if (isHiBONType!T) {
    return net.dartIndex(value.toDoc);
}
