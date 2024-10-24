module foundation.wasm;

import core.bitop : bsf, bsr;
public import core.bitop : popcnt, rol, ror;
import std.traits;

@safe:
@nogc nothrow {
    union b32 {
        int i32;
        float f32;
    }

    int reinterpret32(float x) {
        b32 result;
        result.f32 = x;
        return result.i32;
    }

    float reinterpret32(int x) {
        b32 result;
        result.i32 = x;
        return result.f32;
    }

    union b64 {
        long i64;
        double f64;
    }

    long reinterpret64(double x) {
        b64 result;
        result.f64 = x;
        return result.i64;
    }

    double reinterpret64(long x) {
        b64 result;
        result.i64 = x;

        return result.f64;
    }

    template FloatAsInt(F) if (isFloatingPoint!F) {
        static if (F.sizeof == int.sizeof) {
            alias FloatAsInt = int;
        }
        else {
            alias FloatAsInt = long;
        }
    }

    union Float(F) {
        F f;
        FloatAsInt!F i;
    }

    F snan2(F, T)(T x) if (isFloatingPoint!F && is(T == FloatAsInt!F)) {
        Float!F result;
        result.f = F.nan;
        result.i |= x;
        return result.f;
    }

    auto snan(T)(T x) if (isIntegral!T) {
        static if (T.sizeof == int.sizeof) {
            return reinterpret32(x);
        }
        else {
            return reinterpret64(x);
        }
    }

    T clz(T)(T val) if (isIntegral!T) {
        if (val == 0) {
            return T.sizeof * 8;
        }
        return T(T.sizeof * 8 - 1) - T(bsr(val));
    }

    T ctz(T)(T val) if (isIntegral!T) {
        if (val == 0) {
            return T.sizeof * 8;
        }
        return bsf(val);
    }

    T rotl(T)(T x, T y) if (isUnsigned!T) {
        enum mask = uint(T.sizeof * 8 - 1);
        return rol(x, (cast(uint) y) & mask);
    }

    T rotr(T)(T x, T y) if (isUnsigned!T) {
        enum mask = uint(T.sizeof * 8 - 1);
        return ror(x, (cast(uint) y) & mask);
    }
}

T div(T)(T x, T y) if (isIntegral!T) {
    static if (isSigned!T) {
        error(!(x == T.min && y == T(-1)), "Overflow (%d / %d)", x, y);
    }
    error(y != 0, "Division with zero");

    return x / y;
}

T rem(T)(T x, T y) if (isIntegral!T) {
    static if (isSigned!T) {
        if (x == T.min && y == T(-1))
            return T(0);
        error(!(x == T.min && y == T(-1)), "Overflow (%d %% %d)", x, y);
    }
    error(y != 0, "Division with zero");

    return x % y;
}

T fmin(T)(T x, T y) if (isFloatingPoint!T) {
    import std.math : isNaN;

    if (isNaN(x) || isNaN(y)) {
        return T.nan;
    }
    return (x < y) ? x : y;
}

T fmax(T)(T x, T y) if (isFloatingPoint!T) {
    import std.math : isNaN;

    if (isNaN(x) || isNaN(y)) {
        return T.nan;
    }
    return (x > y) ? x : y;
}

T trunc(T, F)(F _from) if (isIntegral!T && isFloatingPoint!F) {
    import std.format;
    import std.math;

    static if (is(F == double) && (T.sizeof == int.sizeof)) {
        enum int_max = T.max;
    }
    else {
        enum int_max = cast(T)((ulong.max << (T.sizeof * 8 - isSigned!T - F.mant_dig)) & T.max);
    }
    error((_from >= T.min) && (_from <= int_max) || (abs(_from) < 1.0),
            format("overflow %a int_max=%x", _from, int_max));
    return cast(T) _from;
}

void error(const bool flag, string msg, string file = __FILE__, size_t line = __LINE__) {
    import std.exception;

    if (!flag) {
        throw new Exception(msg, file, line);
    }
}

void error(Args...)(const bool flag, string fmt, Args args, string file = __FILE__, size_t line = __LINE__) {
    import std.exception;
    import std.format;

    if (!flag) {
        throw new Exception(format(fmt, args), file, line);
    }
}

void assert_trap(E)(lazy E expression, string msg = null, string file = __FILE__, size_t line = __LINE__) {
    import std.exception : assertThrown;

    assertThrown(expression, msg, file, line);
}
