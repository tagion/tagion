module tagion.utils.convert;

import std.algorithm;
import std.array;
import std.range;
import std.traits;
import std.exception;
import std.string : representation;
import std.typecons;
import std.range.primitives : isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.errors.tagionexceptions;

@safe:

enum Prefix {
    hex = "0x",
    HEX = "0X",
    bin = "0b",
    BIN = "0B",
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

uint convertBase(const(char[]) text) pure nothrow {
    import std.uni : sicmp;

    if (sicmp(text[0 .. min(Prefix.hex.length, $)], Prefix.hex) == 0) {
        return 16;
    }
    if (sicmp(text[0 .. min(Prefix.bin.length, $)], Prefix.bin) == 0) {
        return 2;
    }
    return 10;
}

unittest {
    assert("0xA".convertBase == 16);
    assert("0b1".convertBase == 2);
    assert("129".convertBase == 10);
}

T convert(T)(const(char)[] text) if (isIntegral!T) {
    import std.format;
    import std.conv : to;
    import std.uni : sicmp;

    check(text.length > 0, "Can not convert an empty string");
    const negative = text[0] == '-';
    size_t pos = negative || (text[0] == '+');
    static if (isUnsigned!T) {
        check(!negative, format("Negative number can not convert to %s", T.stringof));
    }
    const base = convertBase(text[pos .. $]);
    if (base !is 10) {
        pos += Prefix.hex.length;
    }
    const text_stripped = text[pos .. $]
        .representation
        .map!(c => cast(const(char)) c)
        .filter!(c => c != '_')
        .array;
    auto result = cast(T)(text_stripped.to!(Unsigned!T)(base));
    if (isSigned!T && negative) {
        result = -result;
    }
    return result;
}

unittest {
    assert("42".convert!uint == 42);
    assert("42000000".convert!ulong == 42_000_000);

    assert("0xab".convert!int == 0xAB);
    assert("-0xab".convert!int == -0xAB);

}

union Float(F) if (isFloatingPoint!F) {
    static if (F.sizeof == int.sizeof) {
        alias I = int;
        alias U = uint;
        enum mask = 0x0060_0000;
    }
    else {
        alias I = long;
        alias U = ulong;
        enum mask = 0xC_0000_0000_0000L;
    }
    enum mant_mask = (U(1) << (F.mant_dig - 1)) - 1;
    enum exp_mask = I.max & (~mant_mask);
    enum arithmetic_mask = mant_mask >> 1;
    enum canonical_mask = mant_mask & (~arithmetic_mask);
    F number;
    I raw;
}

bool isInteger(const(char)[] text) pure nothrow {
    import std.ascii : toUpper;

    if (text) {
        if (only('-', '+').canFind(text[0])) {
            return isInteger(text[1 .. $]);
        }
        const base = convertBase(text);
        if (only(2, 16).canFind(base)) {
            text = text[Prefix.hex.length .. $];
        }
        foreach (c; text) {
            if (c < '0') {
                return false;
            }
            switch (base) {
            case 10:
                if (c > '9') {
                    return false;
                }
                break;
            case 16:
                if (c > '9') {
                    const C = toUpper(c);
                    if ((C < 'A') || (C > 'F')) {
                        return false;
                    }
                }
                break;
            case 2:
                if (c > '1') {
                    return false;
                }
                break;
            default:
                return false;
            }

        }
        return true;
    }
    return false;
}

F convert(F)(const(char)[] text) if (isFloatingPoint!F) {
    import std.format;
    import std.uni : sicmp;

    check(text.length > 0, "Can not convert an empty string");
    const negative = text[0] == '-';
    const pos = negative || (text[0] == '+');
    enum {
        NaN = "nan",
        Infinity = "infinity",
        Inf = "inf",
        Canonical = "canonical",
        Arithmetic = "arithmetic",
    }
    if (sicmp(text[pos .. min(pos + NaN.length, $)], NaN) == 0) {
        auto quiet = text.splitter(':').drop(1);
        alias Number = Float!F;

        Number result;
        result.number = (negative) ? -F.nan : F.nan;
        if (!quiet.empty && (sicmp(quiet.front, Canonical) != 0)) {

            static if (F.sizeof == uint.sizeof) {
                enum mask = 0x0060_0000;
                enum arithmetic_mask = 0x0020_0000;
            }
            else {
                enum mask = 0xC_0000_0000_0000L;
                enum arithmetic_mask = 0x4_0000_0000_0000L;
            }
            result.raw &= ~(mask);

            if (sicmp(quiet.front, Arithmetic) == 0) {
                result.raw |= arithmetic_mask;
            }
            else {
                const signal_mask = convert!(Number.U)(quiet.front);
                result.raw |= signal_mask;
            }
        }
        return result.number;
    }
    if ((sicmp(text, Inf) == 0) || (sicmp(text, Infinity) == 0)) {
        return (negative) ? -F.infinity : F.infinity;
    }
    version(none)
    if (isInteger(text)) {
        const x = convert!long(text);

        enum max_dig = long(1) << F.mant_dig;
        import std.math : abs;

        check(abs(x) <= max_dig, format("Decimal digits overflow %d for %s", x, F.stringof));
        return F(x);
    }
    const spec = singleSpec("%f");
    return unformatValue!F(text, spec);
}

template tryConvert(T) {
    import tagion.utils.Result;

    Result!T tryConvert(const(char[]) text) nothrow {
        try {
            return result(text.convert!T);
        }
        catch (Exception e) {
            return Result!T(e);
        }
        assert(0);
    }
}

unittest {
    import std.math;

    void convert_test(F)() {
        { // Canonical and Arithmetic nan types
            const x1 = "nan".convert!F;
            assert(x1.isNaN);
            const x2 = "nan:arithmetic".convert!F;
            assert(x2.isNaN);
            const x3 = "nan:0x8889".convert!F;
            assert(x3.isNaN);
            const x4 = "nan:canonical".convert!F;
            assert(x4.isNaN);
        }
        { // infinity
            const y1 = "inf".convert!F;
            assert(y1 == F.infinity);
            const y2 = "infinity".convert!F;
            assert(y2 == F.infinity);
        }
        { // -infinity
            const y = "-inf".convert!F;
            assert(y == -F.infinity);
            const x = "-nan".convert!F;
            assert(x.isNaN);
            assert(x.signbit);
        }
    }

    convert_test!float;
    convert_test!double;

    { // nan with signal information
        Float!float x1;
        x1.number = "nan:0x200000".convert!float;
        assert(x1.raw == 0x7fa0_0000);
    }
    { // ditto with -nan
        Float!float x1;
        x1.number = "-nan:0x200000".convert!float;
        assert(x1.raw == 0xffa0_0000);
    }
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
