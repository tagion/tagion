
interface Hash {
    static immutable(Hash) opCall(const(ubyte)[] buffer);
    static immutable(Hash) opCall(const(H) left, const(H) right);
}
