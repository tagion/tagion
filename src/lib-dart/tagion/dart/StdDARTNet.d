module tagion.dart.StdDARTNet;

import tagion.hashgraph.Net : StdSecureNet;
import tagion.hashgraph.GossipNet : DARTNet;

class StdDARTNet : StdSecureNet, DARTNet {
    import tagion.crypto.secp256k1.NativeSecp256k1 : NativeSecp256k1;

    this(NativeSecp256k1 crypt) {
        super(crypt);
    }

    immutable(ubyte[]) load(const(ubyte[]) key) {
        return null;
    }
    void save(const(ubyte[]) key, immutable(ubyte[]) data, const uint rim) {
        assert(0, "Not implemented!");
    }
    void erase(const(ubyte[]) key) {
        assert(0, "Not implemented!");
    }
}
