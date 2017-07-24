module bakery.crypto.Hash;

@safe
interface Hash {
    static immutable(Hash) opCall(const(ubyte)[] buffer) pure nothrow;
    static immutable(Hash) opCall(const(Hash) left, const(Hash) right) pure nothrow;
    static immutable(uint) buffer_size() pure nothrow;
    immutable(ubyte)[] signed() const pure nothrow;
}
