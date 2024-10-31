module foundation.wasm;

import core.bitop : bsf, bsr;
public import core.bitop : popcnt, rol, ror;
import std.traits;
import foundation.error;

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

