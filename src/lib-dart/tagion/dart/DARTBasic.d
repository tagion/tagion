module tagion.dart.DARTBasic;

import tagion.basic.Types : DARTIndex;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONType : isHiBONType;
import tagion.hibon.HiBONType : HiBONPrefix, STUB;

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
     return DARTIndex(net.calcHash(doc));
}

@safe
const(DARTIndex) dartIndex(T)(const(HashNet) net, T value) if (isHiBONType!T) {
    return net.dartIndex(value.toDoc);
}
