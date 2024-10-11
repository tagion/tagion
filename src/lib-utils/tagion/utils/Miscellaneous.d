/// Miscellaneous functions
module tagion.utils.Miscellaneous;

import std.algorithm;
import std.array;
import std.range;
import std.traits;
import std.exception;
import std.range.primitives : isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.errors.tagionexceptions;

@safe:

enum Prefix {
    hex="0x",
    HEX="0X",
    bin="0b",
    BIN="0B",
}

enum HEX_SEPARATOR = '_';
Buffer decode(const(char[]) hex) pure {
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

class ConvertException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!ConvertException;

T convert(T)(const(char)[] text) if(isIntegral!T) {
    import std.format;
    import std.conv : to;
    check(text.length > 0, "Can not convert an empty string");
    const negative=text[0] == '-';
    static if (isUnsigned!T) {
        check(!negative, format("Negative number can not convert to %s", T.stringof));
    }

    uint base=10;
    text=text[negative..$];
    if (text[0..min(Prefix.hex.length,$)] == Prefix.hex) {
        base=16;
        text=text[Prefix.hex.length..$];
    }
    else if (text[0..min(Prefix.bin.length,$)] == Prefix.bin) {
        base=2;
        text=text[Prefix.bin.length..$];
    }
    auto result=cast(T)(text.to!(Unsigned!T)(base));
    if (isSigned!T && negative) {
        result=-result;
    }
    return result;
}

unittest {
    assert("42".convert!uint == 42);
    assert("42_000_000".convert!ulong == 42_000_000);

    assert("0xab".convert!int == 0xAB);
    assert("-0xab".convert!int == -0xAB);

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
string cutHex(BUF)(BUF buf) pure if (isBufferType!BUF) {
    import std.format;
    import std.algorithm : min;

    enum LEN = ulong.sizeof;
    return format!"%(%02x%)"(buf[0 .. min(LEN, buf.length)]);
}

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

@nogc
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

Buffer xor(Range)(Range range) pure if (isInputRange!Range && is(ElementType!Range : const(ubyte[])))
in (!range.empty)
do {
    import std.array : array;
    import std.range : tail;

    auto result = new ubyte[range.front.length];
    range
        .each!(b => result[] ^= b[]);
    return (() @trusted => assumeUnique(result))();
}
