module tagion.utils.Miscellaneous;

import std.algorithm : map;
import std.algorithm.iteration : cumulativeFold, fold;
import std.array;
import std.exception;
import std.range.primitives : isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.basic.tagionexceptions : TagionException;

@trusted
string toHexString(bool UCASE = false, BUF)(BUF buffer) pure nothrow
if (isBufferType!BUF) {
    static if (UCASE) {
        enum hexdigits = "0123456789ABCDEF";
    }
    else {
        enum hexdigits = "0123456789abcdef";
    }
    uint i = 0;
    char[] text = new char[buffer.length * 2];
    foreach (b; buffer) {
        text[i++] = hexdigits[b >> 4];
        text[i++] = hexdigits[b & 0xf];
    }

    return assumeUnique(text);
}

alias hex = toHexString;

unittest {
    {
        enum value = "CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90";
        auto buf = decode(value);
        assert(buf.length * 2 == value.length);
        assert(buf.toHexString!true == value);
    }
    {
        enum value = "30440220182A108E1448DC8F1FB467D06A0F3BB8EA0533584CB954EF8DA112F1D60E39A202201C66F36DA211C087F3AF88B50EDF4F9BDAA6CF5FD6817E74DCA34DB12390C6E9";
        auto buf = decode(value);
        assert(buf.length * 2 == value.length);
        assert(buf.toHexString!true == value);
    }

}

enum HEX_SEPARATOR = '_';

@safe Buffer decode(const(char[]) hex) pure
in {
    if (hex.replace(HEX_SEPARATOR, "").length % 2 != 0)
        throw new TagionException("Hex string length not even");
}
do {
    int to_hex(const(char) c) {
        if ((c >= '0') && (c <= '9')) {
            return cast(ubyte)(c - '0');
        }
        else if ((c >= 'a') && (c <= 'f')) {
            return c - 'a' + 10;
        }
        else if ((c >= 'A') && (c <= 'F')) {
            return cast(ubyte)(c - 'A') + 10;
        }
        throw new TagionException("Bad char '" ~ c ~ "'");
    }

    immutable buf_size = hex.length / 2;
    ubyte[] result = new ubyte[buf_size];
    uint j;
    bool event;
    ubyte part;
    foreach (c; hex) {
        if (c != HEX_SEPARATOR) {
            //            writefln("j=%d len=%d", j, result.length);
            part <<= 4;
            part |= to_hex(c);

            if (event) {
                result[j] = part;
                part = 0;
                j++;
            }
            event = !event;
        }
    }
    return result.idup;
}

/++
 + Converts on the first part of the buffer to a Hex string
 + Used for debugging
 +
 + Params:
 +     buf = is a buffer type like a byte array
 + Returns:
 +     The 16 first hex digits of the buffer
+/
@safe
string cutHex(bool UCASE = false, BUF)(BUF buf) pure if (isBufferType!BUF) {
    import std.format;

    enum LEN = ulong.sizeof;
    if (buf.length < LEN) {
        return buf[0 .. $].toHexString!UCASE;
    }
    else {
        return buf[0 .. LEN].toHexString!UCASE;
    }
}

@safe
protected Buffer _xor(const(ubyte[]) a, const(ubyte[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    import tagion.utils.Gene : gene_xor;

    const _a = cast(const(ulong[])) a;
    const _b = cast(const(ulong[])) b;
    return cast(Buffer) gene_xor(_a, _b);
}

@safe
const(Buffer) xor(scope const(ubyte[]) a, scope const(ubyte[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    import tagion.utils.Gene : gene_xor;

    const _a = cast(const(ulong[])) a;
    const _b = cast(const(ulong[])) b;
    return cast(Buffer) gene_xor(_a, _b);
}

@nogc @safe
void xor(ref scope ubyte[] result, scope const(ubyte[]) a, scope const(ubyte[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    import tagion.utils.Gene : gene_xor;

    const _a = cast(const(ulong[])) a;
    const _b = cast(const(ulong[])) b;
    auto _result = cast(ulong[]) result;
    gene_xor(_result, _a, _b);
}

@safe
Buffer xor(Range)(scope Range range) pure if (isInputRange!Range) {
    import std.array : array;
    import std.range : tail;

    return range
        .cumulativeFold!((a, b) => _xor(a, b))
        .tail(1)
        .front;
}
