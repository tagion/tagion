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

    F snan2(F, T)(T x) if (isFloatingPoint!F) {
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

mixin template IntegralTruncLimits(T, F) if (isIntegral!T && isFloatingPoint!F) {
    static if (is(F == double)) {
        static if (T.sizeof == int.sizeof) {
            static if (isSigned!T) {
                enum max_int = 0x1p+31;
                enum min_int = -0x1.000_0000_1FFF_FFp+31;
            }
            else {
                enum max_int = 0x1p+32;
                enum min_int = 0x0p+0;
            }
        }
        else {
            static if (isSigned!T) {
                enum max_int = 0x1p+63;
                enum min_int = -0x1p+63;
            }
            else {
                enum max_int = 0x1p+64;
                enum min_int = 0x0p+0; 
            }
        }
    }
    else {
        static if (T.sizeof == int.sizeof) {
            static if (isSigned!T) {
                enum max_int = 0x1p+31f;
                enum min_int = -0x1p+31F;
            }
            else {
                enum max_int = 0x1p+32F-1.0F;
                enum min_int = 0x0p+0F;
            }
        }
        else {
            static if (isSigned!T) {
                enum max_int = 0x1p+63F-1.0F;
                enum min_int = -0x1p+63F;
            }
            else {
                enum max_int = 0x1p+64F-1.0F;
                enum min_int = 0x1p+0F;
            }
        }
    }
 }

T trunc(T, F)(F x) if (isIntegral!T && isFloatingPoint!F) {
    import std.math : abs;
    import std.format;
    mixin IntegralTruncLimits!(T, F); 
    error((x >= min_int) && (x < max_int) || (abs(x) < 1.0),
            format("overflow %a [%a..%a]", x, min_int, max_int));
    return cast(T) x;
}

T trunc_sat(T, F)(F x) @trusted if (isIntegral!T && isFloatingPoint!F) {
    import std.math : isNaN;
    mixin IntegralTruncLimits!(T, F); 
    if (x < min_int) {
        return T.min;
    }
    if (x >= max_int) {
        return T.max;
    }
    if (x.isNaN) {
        return T.init;
    }
    return cast(T) x;
}

double promote(float x) {
    import std.math : isNaN;
    if (x.isNaN) {
         Float!double snan;
         snan.f=x;
        return snan.f;
        //return snan2!double((cast(long)snan.i));
    }
    return cast(double)x;
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
