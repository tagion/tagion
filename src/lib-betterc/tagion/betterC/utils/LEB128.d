/// \file LEB128.d

module tagion.betterC.utils.LEB128;

@nogc:

import std.format;
import traits = std.traits : isIntegral, isSigned, isUnsigned;
import std.typecons;

//import tagion.basic.tagionexceptions;
import std.algorithm.comparison : min;
import std.algorithm.iteration : map, sum;
import tagion.betterC.utils.Bailout;
import tagion.betterC.utils.BinBuffer;

//import std.stdio;

// @safe
// class LEB128Exception : TagionException {
//     this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
//         super( msg, file, line );
//     }
// }

// alias check=Check!LEB128Exception;

size_t calc_size(const(ubyte[]) data) {
    foreach (i, d; data) {
        if ((d & 0x80) == 0) {
            //check(i <= ulong.sizeof+1, "LEB128 overflow");
            return i + 1;
        }
    }
    // check(0, "LEB128 bad format");
    assert(0);
}

@safe
size_t calc_size(T)(const T v) pure if (isUnsigned!(T)) {
    size_t result;
    ulong value = v;
    do {
        result++;
        value >>= 7;
    }
    while (value);
    return result;
}

@safe
size_t calc_size(T)(const T v) pure if (isSigned!(T)) {
    if (v == T.min) {
        return T.sizeof + (is(T == int) ? 1 : 2);
    }
    ulong value = ulong((v < 0) ? -v : v);
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

void encode(T)(ref BinBuffer buffer, const T v) if (isUnsigned!T && isIntegral!T) {
    ubyte[T.sizeof + 2] data;
    alias BaseT = TypedefType!T;
    BaseT value = cast(BaseT) v;
    foreach (i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        if (value == 0) {
            buffer.write(data[0 .. i + 1]);
            return;
        }
        d |= 0x80;
    }
    assert(0);
}

void encode(T)(ref BinBuffer buffer, const T v) if (isSigned!T && isIntegral!T) {
    enum DATA_SIZE = (T.sizeof * 9 + 1) / 8 + 1;
    ubyte[DATA_SIZE] data;
    //    size_t index;
    if (v == T.min) {
        foreach (ref d; data[0 .. $ - 1]) {
            d = 0x80;
        }
        data[$ - 1] = (T.min >> (7 * (DATA_SIZE - 1))) & 0x7F;
        buffer.write(data);
        return;
    }
    T value = v;
    foreach (i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        /* sign bit of byte is second high order bit (0x40) */
        if (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40))) {
            buffer.write(data[0 .. i + 1]);
            return;
        }
        d |= 0x80;
    }
    // check(0, "Bad LEB128 format");
    assert(0);
}

alias DecodeLEB128(T) = Tuple!(T, "value", size_t, "size");

DecodeLEB128!T decode(T = ulong)(const(ubyte[]) data) if (isUnsigned!T) {
    alias BaseT = TypedefType!T;
    ulong result;
    uint shift;
    enum MAX_LIMIT = T.sizeof * 8;
    size_t len;
    foreach (i, d; data) {
        // check(shift < MAX_LIMIT,
        //     message("LEB128 decoding buffer over limit of %d %d", MAX_LIMIT, shift));

        result |= (d & 0x7FUL) << shift;
        if ((d & 0x80) == 0) {
            len = i + 1;
            static if (!is(BaseT == ulong)) {
                check(result <= BaseT.max, message("LEB128 decoding overflow of %x for %s", result, T
                        .stringof));
            }
            return DecodeLEB128!T(cast(BaseT) result, len);
        }
        shift += 7;
    }
    // check(0, message("Bad LEB128 format for type %s", T.stringof));
    assert(0);
}

DecodeLEB128!T decode(T = long)(const(ubyte[]) data) if (isSigned!T) {
    alias BaseT = TypedefType!T;
    long result;
    uint shift;
    enum MAX_LIMIT = T.sizeof * 8;
    size_t len;
    foreach (i, d; data) {
        // check(shift < MAX_LIMIT, "LEB128 decoding buffer over limit");
        result |= (d & 0x7FL) << shift;
        shift += 7;
        if ((d & 0x80) == 0) {
            if ((shift < long.sizeof * 8) && ((d & 0x40) != 0)) {
                result |= (~0L << shift);
            }
            len = i + 1;
            // static if (!is(BaseT==long)) {
            //     // check((T.min <= result) && (result <= T.max),
            //     //     message("LEB128 out of range %d for %s", result, T.stringof));
            // }
            return DecodeLEB128!T(cast(BaseT) result, len);
        }
    }
    // check(0, message("Bad LEB128 format for type %s", T.stringof));
    assert(0);
}

///
unittest {
    import std.algorithm.comparison : equal;

    void ok(T)(T x, const(ubyte[]) expected) {
        BinBuffer encoded;
        encode(encoded, x);
        assert(equal(encoded.serialize, expected));
        assert(calc_size(x) == expected.length);
        assert(calc_size(expected) == expected.length);
        const decoded = decode!T(expected);
        assert(decoded.size == expected.length);
        assert(decoded.value == x);
    }

    {

        const(ubyte[5]) buffer_0 = [255, 255, 255, 255, 7];
        ok!int(int.max, buffer_0);
        const(ubyte[1]) buffer_1 = [27];
        ok!ulong(27, buffer_1);
        const(ubyte[2]) buffer_2 = [167, 21];
        ok!ulong(2727, buffer_2);
        const(ubyte[3]) buffer_3 = [215, 210, 16];
        ok!ulong(272727, buffer_3);
        const(ubyte[4]) buffer_4 = [151, 204, 128, 13];
        ok!ulong(27272727, buffer_4);
        const(ubyte[5]) buffer_5 = [181, 202, 212, 168, 5];
        ok!ulong(1427449141, buffer_5);
        const(ubyte[10]) buffer_6 = [
            255, 255, 255, 255, 255, 255, 255, 255, 255, 1
        ];
        ok!ulong(ulong.max, buffer_6);
    }

    {
        const(ubyte[1]) buffer_0 = [127];
        ok!int(-1, buffer_0);
        const(ubyte[5]) buffer_1 = [255, 255, 255, 255, 7];
        ok!int(int.max, buffer_1);
        const(ubyte[5]) buffer_2 = [128, 128, 128, 128, 120];
        ok!int(int.min, buffer_2);
        const(ubyte[5]) buffer_3 = [255, 255, 255, 255, 7];
        ok!int(int.max, buffer_3);
        const(ubyte[5]) buffer_4 = [128, 128, 128, 128, 120];
        ok!long(int.min, buffer_4);
        const(ubyte[5]) buffer_5 = [255, 255, 255, 255, 7];
        ok!long(int.max, buffer_5);

        const(ubyte[1]) buffer_6 = [27];
        ok!long(27, buffer_6);
        const(ubyte[2]) buffer_7 = [167, 21];
        ok!long(2727, buffer_7);
        const(ubyte[3]) buffer_8 = [215, 210, 16];
        ok!long(272727, buffer_8);
        const(ubyte[4]) buffer_9 = [151, 204, 128, 13];
        ok!long(27272727, buffer_9);

        const(ubyte[5]) buffer_10 = [181, 202, 212, 168, 5];
        ok!long(1427449141, buffer_10);

        const(ubyte[3]) buffer_11 = [192, 187, 120];
        ok!int(-123456, buffer_11);

        const(ubyte[1]) buffer_12 = [101];
        ok!long(-27, buffer_12);
        const(ubyte[2]) buffer_13 = [217, 106];
        ok!long(-2727, buffer_13);
        const(ubyte[3]) buffer_14 = [169, 173, 111];
        ok!long(-272727, buffer_14);
        const(ubyte[4]) buffer_15 = [233, 179, 255, 114];
        ok!long(-27272727, buffer_15);
        const(ubyte[5]) buffer_16 = [203, 181, 171, 215, 122];
        ok!long(-1427449141L, buffer_16);

        const(ubyte[1]) buffer_17 = [127];
        ok!long(-1L, buffer_17);

        const(ubyte[10]) buffer_18 = [
            254, 255, 255, 255, 255, 255, 255, 255, 255, 0
        ];
        ok!long(long.max - 1, buffer_18);
        const(ubyte[10]) buffer_19 = [
            255, 255, 255, 255, 255, 255, 255, 255, 255, 0
        ];
        ok!long(long.max, buffer_19);
        const(ubyte[10]) buffer_20 = [
            129, 128, 128, 128, 128, 128, 128, 128, 128, 127
        ];
        ok!long(long.min + 1, buffer_20);
        const(ubyte[10]) buffer_21 = [
            128, 128, 128, 128, 128, 128, 128, 128, 128, 127
        ];
        ok!long(long.min, buffer_21);
    }

    { // Bug fix
        assert(calc_size(-77) == 2);
        const(ubyte[2]) buffer_22 = [179, 127];
        ok!int(-77, buffer_22);
    }

}
