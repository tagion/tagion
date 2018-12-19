module tagion.dart.StdDARTNet;

class StdDARTNet : StdSecureNet, DARTNet {
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
