module tagion.utils.LEB128;

import traits = std.traits : isSigned, isUnsigned, isIntegral;
import std.typecons;
import std.format;
import tagion.basic.tagionexceptions;
import std.algorithm.comparison : min;
import std.algorithm.iteration : map, sum;

@safe:
@nogc
class LEB128Exception : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!LEB128Exception;

/++
 Returns:
 The size in bytes of the LEB128
 No error size 0 is returned
+/
@nogc
size_t calc_size(const(ubyte[]) data) pure nothrow {
    foreach (i, d; data) {
        if ((d & 0x80) == 0) {
            if (i > ulong.sizeof + 1) {
                return 0;
            }
            return i + 1;
        }
    }
    return data.length;
}

@nogc
size_t calc_size(T)(const T v) pure nothrow if (isUnsigned!(T)) {
    size_t result;
    ulong value = v;
    do {
        result++;
        value >>= 7;
    }
    while (value);
    return result;
}

/// Returns: the max size to store a T as a
template DataSize(T) if (isIntegral!T) {
    static if (isUnsigned!T) {
        enum DataSize = T.sizeof + 2;
    }
    else {
        enum DataSize = (T.sizeof * 9 + 1) / 8 + 1;
    }
}

@nogc
size_t calc_size(T)(const T v) pure nothrow if (isSigned!(T)) {
    if (v == T.min) {
        return T.sizeof + (is(T == int) ? 1 : 2);
    }
    T value = v;
    static if (is(T == long)) {
        if ((value >> (long.sizeof * 8 - 2)) == 1UL) {
            return long.sizeof + 2;
        }
    }
    size_t result;
    // auto uv=(v < 0)?-v:v;
    // T nv=-v;

    ubyte d;
    do {
        d = value & 0x7f;
        result++;
        value >>= 7;
    }
    while ((((value != 0) || (d & 0x40)) && ((value != -1) || !(d & 0x40))));
    return result;
}

immutable(ubyte[]) encode(T)(const T v) pure if (isUnsigned!T && isIntegral!T) {
    ubyte[DataSize!T] data;
    alias BaseT = TypedefType!T;
    BaseT value = cast(BaseT) v;
    foreach (i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        if (value == 0) {
            return data[0 .. i + 1].idup;
        }
        d |= 0x80;
    }
    assert(0);
}

immutable(ubyte[]) encode(T)(const T v) pure if (isSigned!T && isIntegral!T) {
    enum DATA_SIZE = (T.sizeof * 9 + 1) / 8 + 1;
    ubyte[DataSize!T] data;
    if (v == T.min) {
        foreach (ref d; data[0 .. $ - 1]) {
            d = 0x80;
        }
        data[$ - 1] = (T.min >> (7 * (DATA_SIZE - 1))) & 0x7F;
        return data.dup;
    }
    T value = v;
    foreach (i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        /* sign bit of byte is second high order bit (0x40) */
        if (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40))) {
            return data[0 .. i + 1].idup;
        }
        d |= 0x80;
    }
    check(0, "Bad LEB128 format");
    assert(0);
}

alias DecodeLEB128(T) = Tuple!(T, "value", size_t, "size");
enum ErrorValue(T) = DecodeLEB128!T(T.init, 0);
/++
 Converts a ubyte string to LEB128 number
 Returns:
 The value and the size
 In case of an error this size is set to zero
+/
@nogc
DecodeLEB128!T decode(T = ulong)(const(ubyte[]) data) pure nothrow
if (isUnsigned!T) {
    alias BaseT = TypedefType!T;
    ulong result;
    uint shift;
    enum MAX_LIMIT = T.sizeof * 8;
    size_t len;
    foreach (i, d; data) {
        if (shift >= MAX_LIMIT) {
            return ErrorValue!T;
        }
        result |= (d & 0x7FUL) << shift;
        if ((d & 0x80) == 0) {
            len = i + 1;
            static if (!is(BaseT == ulong)) {
                if (result > BaseT.max) {
                    return ErrorValue!T;
                }
            }
            return DecodeLEB128!T(cast(BaseT) result, len);
        }
        shift += 7;
    }
    return ErrorValue!T;
}

/++
 Converts a ubyte string to LEB128 number
 Returns:
 The value and the size
 In case of an error this size is set to zero
+/
@nogc
DecodeLEB128!T decode(T = long)(const(ubyte[]) data) pure nothrow if (isSigned!T) {
    alias BaseT = TypedefType!T;
    long result;
    uint shift;
    enum MAX_LIMIT = T.sizeof * 8;
    size_t len;
    foreach (i, d; data) {
        if (shift >= MAX_LIMIT) {
            return ErrorValue!T;
        }
        //        check(shift < MAX_LIMIT, "LEB128 decoding buffer over limit");
        result |= (d & 0x7FL) << shift;
        shift += 7;
        if ((d & 0x80) == 0) {
            if ((shift < long.sizeof * 8) && ((d & 0x40) != 0)) {
                result |= (~0L << shift);
            }
            len = i + 1;
            static if (!is(BaseT == long)) {
                if (T.min > result) {
                    return ErrorValue!T;
                }
            }
            return DecodeLEB128!T(cast(BaseT) result, len);
        }
    }
    return ErrorValue!T;
}

///
unittest {
    import std.algorithm.comparison : equal;

    void ok(T)(T x, const(ubyte[]) expected) {
        const encoded = encode(x);
        assert(equal(encoded, expected));
        assert(calc_size(x) == expected.length);
        assert(calc_size(expected) == expected.length);
        const decoded = decode!T(expected);
        assert(decoded.size == expected.length);
        assert(decoded.value == x);
    }

    {
        ok!int(int.max, [255, 255, 255, 255, 7]);
        ok!ulong(27, [27]);
        ok!ulong(2727, [167, 21]);
        ok!ulong(272727, [215, 210, 16]);
        ok!ulong(27272727, [151, 204, 128, 13]);
        ok!ulong(1427449141, [181, 202, 212, 168, 5]);
        ok!ulong(ulong.max, [255, 255, 255, 255, 255, 255, 255, 255, 255, 1]);
    }

    {
        ok!int(-1, [127]);
        ok!int(int.max, [255, 255, 255, 255, 7]);
        ok!int(int.min, [128, 128, 128, 128, 120]);
        ok!int(int.max, [255, 255, 255, 255, 7]);
        ok!long(int.min, [128, 128, 128, 128, 120]);
        ok!long(int.max, [255, 255, 255, 255, 7]);

        ok!long(27, [27]);
        ok!long(2727, [167, 21]);
        ok!long(272727, [215, 210, 16]);
        ok!long(27272727, [151, 204, 128, 13]);
        ok!long(1427449141, [181, 202, 212, 168, 5]);

        ok!int(-123456, [192, 187, 120]);
        ok!long(-27, [101]);
        ok!long(-2727, [217, 106]);
        ok!long(-272727, [169, 173, 111]);
        ok!long(-27272727, [233, 179, 255, 114]);
        ok!long(-1427449141L, [203, 181, 171, 215, 122]);

        ok!long(-1L, [127]);
        ok!long(long.max - 1, [254, 255, 255, 255, 255, 255, 255, 255, 255, 0]);
        ok!long(long.max, [255, 255, 255, 255, 255, 255, 255, 255, 255, 0]);
        ok!long(long.min + 1, [129, 128, 128, 128, 128, 128, 128, 128, 128, 127]);
        ok!long(long.min, [128, 128, 128, 128, 128, 128, 128, 128, 128, 127]);
    }

    {
        assert(decode!int([127]).value == -1);
    }

    { // Bug fix
        assert(calc_size(-77) == 2);
        ok!int(-77, [179, 127]);
    }
}

DecodeLEB128!T read(T, U:
        const(ubyte))(ref U[] data) pure nothrow {
    const result = decode!T(data);
    data = data[result.size .. $];
    return result;
}

///
unittest {
    const(ubyte)[] buf;
    { // read of empty
        const dec_range = read!ulong(buf);
        assert(dec_range.size == 0);
    }

    buf ~= 1234.encode;
    { // read of one
        const dec_range = read!ulong(buf);
        assert(dec_range.value == 1234);
        assert(dec_range.size == 2);
    }
    buf ~= 2755.encode ~ encode(-0x1245);
    { // read of two
        const dec_range = read!ulong(buf);
        assert(dec_range.value == 2755);
        assert(dec_range.size == 2);
    }
    { // read of the last one
        const dec_range = read!long(buf);
        assert(dec_range.value == -0x1245);
        assert(dec_range.size == 2);
    }
}

bool isInvariant(T)(const(ubyte[]) data) pure nothrow @nogc if (isIntegral!T) {
    import std.algorithm;

    bool result = (data.length > 0) && ((data[0] != 0x80) || ((data.length > 1) && data[0 .. 2] != [0x80, 0x00]));
    static if (isSigned!T) {
        if (result) {
            const negative_count = data.countUntil(0xFF);
            return (negative_count < 0) || ((negative_count + 1 < data.length) && data[negative_count] == 0x7F);
        }
    }
    return result;
}

unittest {
    const(ubyte[]) correct_buf = [0];
    const(ubyte[]) not_correct_buf = [0x80, 0];
    { /// Unsigned data invariant LEB128
        assert(correct_buf.decode!uint.value == not_correct_buf.decode!uint.value);
        assert(correct_buf.isInvariant!uint);
        assert(!not_correct_buf.isInvariant!uint);
    }

    {
        assert(correct_buf.isInvariant!int);
        assert(!not_correct_buf.isInvariant!int);
        const(ubyte[]) correct_buf_negative = [0x7F];
        const(ubyte[]) not_correct_buf_negative = [0xFF, 0x7F];
        const(ubyte[]) not_correct_buf_negative_2 = [0xFF, 0xFF, 0xFF, 0x7F];
        assert(correct_buf_negative.isInvariant!int);
        assert(!not_correct_buf_negative.isInvariant!int);
        assert(!not_correct_buf_negative_2.isInvariant!int);

    }
}
