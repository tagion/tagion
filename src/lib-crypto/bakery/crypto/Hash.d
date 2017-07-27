module bakery.crypto.Hash;

@safe
immutable(char)[] hex(alias ucase=false)(const(ubyte)[] buffer) pure nothrow {
    static if ( ucase ) {
        immutable immutable(char)[] hexdigits = "0123456789ABCDEF";
    }
    else {
        immutable immutable(char)[] hexdigits = "0123456789abcdef";
    }
    uint i = 0;
    char[]  text=new char[buffer.length*2];
    foreach (b; buffer)
    {
        text[i++] = hexdigits[b >> 4];
        text[i++] = hexdigits[b & 0xf];
    }

    return text.idup;
}

@safe
interface Hash {
    static immutable(Hash) opCall(const(ubyte)[] buffer) pure nothrow;
    static immutable(Hash) opCall(const(Hash) left, const(Hash) right) pure nothrow;
    static immutable(Hash) opCall(const(Hash) left, const(Hash) right) pure nothrow;
    static immutable(Hash) opCall(const(char)[] str) pure nothrow;
    static immutable(uint) buffer_size() pure nothrow;
    immutable(ubyte)[] signed() const pure nothrow;
    immutable(char)[] hex() const pure nothrow;
}
