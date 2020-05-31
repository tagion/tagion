module tagion.utils.LEB128;

import std.traits : isSigned, isUnsigned, isIntegral;
import std.format;
import tagion.basic.TagionExceptions;

@safe
class LEB128Exception : TagionBasicException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}


alias check=Check!LEB128Exception;

@safe
size_t calc_size(const(ubyte[]) data) pure {
    foreach(i, d;data) {
        if ((d & 0x80) == 0) {
            check(i <= ulong.sizeof+1, "LEB128 overflow");
            return i+1;
        }
    }
    check(0, "LEB128 bad format");
    assert(0);
}

@safe
size_t calc_size(T)(const T v) pure if(isUnsigned!T) {
    size_t result;
    T value=cast(ulong)v;
    do {
        result++;
        value >>= 7;
    } while (value);
    return result;
}


@safe
size_t calc_size(T)(const T v) pure if(isSigned!T) {
    size_t result;
    ulong value=cast(ulong)(v < 0?-v:v);
    do {
        result++;
        value >>= 7;
    } while (value);
    return result;
}

@safe
const(ubyte[]) encode(T)(const T v) pure if(isUnsigned!T && isIntegral!T) {
    ubyte[T.sizeof+1] data;
    T value=v;
    foreach(i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        if (value == 0) {
            return data[0..i+1].dup;
        }
        d |= 0x80;
    }
    assert(0);
}

@safe
const(ubyte[]) encode(T)(const T v) pure if(isSigned!T && isIntegral!T) {
    ubyte[T.sizeof+1] data;
    immutable negative=(v < 0);
    T value=v;
    enum BITS=T.sizeof*8;
    foreach(i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        /* sign bit of byte is second high order bit (0x40) */
        if (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40))) {
            return data[0..i+1].dup;
        }
        d |= 0x80;
    }
    check(0, "Bad format");
    assert(0);
}

T decode(T=ulong)(const(ubyte[]) data, out size_t len) pure if (isUnsigned!T) {
    ulong result;
    uint shift;
    enum MAX_LIMIT=ulong.sizeof*8-7;
    enum LAST_BYTE_MASK=~(~0UL >> MAX_LIMIT);

    foreach(i, d; data) {
        check(!((shift > MAX_LIMIT) && ((d & LAST_BYTE_MASK) == 0)),
            format("LEB128 decoding buffer over limit of %d %d", MAX_LIMIT, shift));
        result |= (d & 0x7FUL) << shift;
        if ((d & 0x80) == 0) {
            len=i+1;
            static if (is(T==ulong)) {
                return result;
            }
            else {
                check(result <= T.max, format("LEB128 decoding overflow of %x for %s", result, T.stringof));
                return cast(T)result;
            }
        }
        shift+=7;
    }
    check(0, "Bad format");
    assert(0);
}

T decode(T=long)(const(ubyte[]) data, out size_t len) pure if (isSigned!T) {
    ulong result;
    uint shift;
    enum MAX_LIMIT=T.sizeof*8-7;
    enum ulong LAST_BYTE_MASK=~(~0UL >> MAX_LIMIT);
    foreach(i, d; data) {
        check(!((shift >= MAX_LIMIT) && ((d & LAST_BYTE_MASK) == 0)), "LEB128 decoding buffer over limit");
        result |= (d & 0x7F) << shift;
        shift+=7;
        if ((d & 0x80) == 0 ) {
            if ((shift < ulong.sizeof) && (d & 0x40)) {
                // signed of byte is set
                result = (~0 << shift);
            }
            const sresult=cast(long)result;
            len=i+1;
            static if (is(T==long)) {
                return sresult;
            }
            else {
                check((T.min <= sresult) && (sresult <= T.max),
                    format("LEB128 out of range for %s", T.sizeof));
                return cast(T)sresult;
            }
        }
    }
    check(0, "Bad format");
    assert(0);
}


unittest {
    import std.stdio;
    import std.algorithm.comparison : equal;
    void ok(T)(T x, const(ubyte[]) expected) {
        assert(equal(encode(x), expected));
        assert(calc_size(x) == expected.length);
        assert(calc_size(expected) == expected.length);
    }

    {
        ok!ulong(27, [27]);
        ok!ulong(2727, [167, 21]);
        ok!ulong(272727, [215, 210, 16]);
        ok!ulong(27272727,  [151, 204, 128, 13]);
        ok!ulong(1427449141, [181, 202, 212, 168, 5]);

    }

    {
        ok!long(27, [27]);
        ok!long(2727, [167, 21]);
        ok!long(272727, [215, 210, 16]);
        ok!long(27272727,  [151, 204, 128, 13]);
        ok!long(1427449141, [181, 202, 212, 168, 5]);

        ok!long(-27, [101]);
        ok!long(-2727,[217, 106]);
        ok!long(-272727, [169, 173, 111]);
        ok!long(-27272727,   [233, 179, 255, 114]);
        ok!long(-1427449141, [203, 181, 171, 215, 122]);
    }
}
