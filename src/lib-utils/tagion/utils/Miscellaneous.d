module tagion.utils.Miscellaneous;

import std.algorithm;
import std.array;
import std.range;
import std.exception;
import std.range.primitives : isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.basic.tagionexceptions : TagionException;

enum HEX_SEPARATOR = '_';

@safe Buffer decode(const(char[]) hex) pure {
    if (hex.replace(HEX_SEPARATOR, "").length % 2 != 0) {
        throw new TagionException("Hex string length not even");
    }
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
string cutHex(BUF)(BUF buf) pure if (isBufferType!BUF) {
    import std.format;
    import std.algorithm : min;

    enum LEN = ulong.sizeof;
    return format!"%(%02x%)"(buf[0 .. min(LEN, buf.length)]);
}

@safe
Buffer xor(scope const(ubyte[]) a, scope const(ubyte[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    import tagion.utils.Gene : gene_xor;

    const _a = cast(const(ulong[])) a;
    const _b = cast(const(ulong[])) b;
    return (() @trusted => cast(Buffer) gene_xor(_a, _b))();
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
Buffer xor(Range)(scope Range range) pure if (isInputRange!Range && is(ElementType!Range : const(ubyte[])))
in (!range.empty)
do {
    import std.array : array;
    import std.range : tail;

    scope result = new ubyte[range.front.length];
    range.each!((rhs) => xor(result, result, rhs));
    return result.idup;
}
