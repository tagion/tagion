module tagion.crypto.Hash;

@safe
immutable(char)[] toHexString(alias ucase=false)(const(ubyte)[] buffer) pure nothrow {
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
immutable(ubyte[]) decode(string hex)
in {
    assert(hex.length % 2 == 0);
}
body {
    int to_hex(const(char) c) {
        if ( (c >= '0') && (c <= '9') ) {
            return cast(ubyte)(c-'0');
        }
        else if ( (c >= 'a') && (c <= 'f') ) {
            return c-'a'+10;
        }
        else if ( (c >= 'A') && (c <= 'F') ) {
            return cast(ubyte)(c-'A')+10;
        }
        assert(0, "Bad char '"~c~"'");
    }
    immutable buf_size=hex.length / 2;
    ubyte[] result=new ubyte[buf_size];
    uint j;
    bool event;
    ubyte part;
    foreach(c; hex) {
        if ( c != '_' ) {
//            writefln("j=%d len=%d", j, result.length);
            part <<=4;
            part |=to_hex(c);

            if ( event ) {
                result[j]=part;
                part=0;
                j++;
            }
            event=!event;
        }
    }
    return result.idup;
}

@safe
interface Hash {
    static immutable(Hash) opCall(const(ubyte)[] buffer) pure nothrow;
    static immutable(Hash) opCall(const(Hash) left, const(Hash) right) pure nothrow;
    static immutable(Hash) opCall(const(Hash) left, const(Hash) right) pure nothrow;
    static immutable(Hash) opCall(const(char)[] str) pure nothrow;
    static immutable(uint) buffer_size() pure nothrow;
    immutable(ubyte)[] digits() const pure nothrow;
    immutable(char)[] hex() const pure nothrow;
}
