module bakery.crypto.Hash;

interface Hash {
    static immutable(Hash) opCall(const(ubyte)[] buffer);
    static immutable(Hash) opCall(const(Hash) left, const(Hash) right);
}
