module foundation.math;

public import core.stdc.math;
import cmath = core.stdc.math;
import std.math : isNaN, signbit;
import std.traits;
import foundation.error;

@safe:
nothrow @nogc {
    template FloatAsInt(F) if (isFloatingPoint!F) {
        static if (F.sizeof == int.sizeof) {
            alias FloatAsInt = int;
        }
        else {
            alias FloatAsInt = long;
        }
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
        F f;
        I i;
    }

    bool isCanonical(F)(F x) @trusted if (isFloatingPoint!F) {
        if (x.isNaN) {
            Float!F result;
            result.f = x;
            printf("result.i & result.canonical_mask =%016x\n",
            result.i & result.canonical_mask);
            return (result.i & result.canonical_mask) != 0;
        }
        return false;
    }

    bool isNaNs(F)(F x, F y, out Float!F result) if (isFloatingPoint!F) {
        if (x.isNaN || y.isNaN) {
            alias Number = Float!F;
            Number _x, _y;
            _x.f = x;
            _y.f = y;
            result.i = _x.i & _y.i;
            if (isCanonical(result.f)) {
                result.i = Number.exp_mask | Number.canonical_mask;
                return true;
            }
            result.i = (_x.i | _y.i) & (~Number.canonical_mask);
            return true;
        }
        return false;
    }

    @trusted
    unittest {
        static void test_isNaNs(F)() {
            alias Number = Float!F;
            Number result;
            F x, y;
            {
                x = F(1);
                y = snan!F();
                printf("x.isNaN %d y.isNaN %d\n", x.isNaN, y.isNaN);
                const is_nans=isNaNs(x, y, result);
                //assert(isNaNs(x, y, result));
                printf("result.i=%016x is_nans=%d\n", result.i, is_nans);
                printf("result.i=%016x\n", result.i & result.canonical_mask);
               printf("isCanonical(result.f) %d", isCanonical(result.f)); 
                //assert(isCanonical(result.f));
            }
        }

        test_isNaNs!(float)();
    }

    import core.stdc.stdio;

    F snan(F, T)(T x = 0) @trusted if (isFloatingPoint!F) {
        if (x & Float!F.mant_mask) {
            Float!F result;
            //result.f = F.nan;

            result.i = x | result.exp_mask;
            return result.f;
        }
        
        return F.nan;
    }

    unittest {
        Float!float x;
        x.f = snan!float(0x7fa0_0000);
        assert(x.i == 0x7fa0_0000);

    }

    int reinterpret32(float x) {
        Float!float result;
        result.f = x;
        return result.i;
    }

    import core.stdc.stdio;

    float reinterpret32(int x) @trusted {
        Float!float result;
        result.i = x;
        return result.f;
    }

    long reinterpret64(double x) {
        Float!double result;
        result.f = x;
        return result.i;
    }

    double reinterpret64(long x) {
        Float!double result;
        result.i = x;
        return result.f;
    }

    float fabsf(float x) {
        if (isNaN(x)) {
            if (signbit(x)) {
                return -x;
            }
            return x;
        }
        return cmath.fabsf(x);
    }

    int equal(T)(T x, T y) if (isNumeric!T) {
        static if (isFloatingPoint!T) {
            if (isNaN(x) || isNaN(y)) {
                Float!T float_x, float_y;
                float_x.f = x;
                float_y.f = y;
                return float_x.i is float_y.i;
            }
        }
        return x == y;
    }

    T add(T)(T x, T y) => arithmetic!("+")(x, y);
    T sub(T)(T x, T y) => arithmetic!("-")(x, y);
    T mul(T)(T x, T y) => arithmetic!("*")(x, y);
    T div(T)(T x, T y) => arithmetic!("/")(x, y);

    import core.stdc.stdio;

    T arithmetic(string op, T)(T x, T y) @trusted if (isFloatingPoint!T) {
        alias Number = Float!T;
        Number result;
        if (isNaNs(x, y, result)) {
            return result.f;
        }
        mixin("result.f=x" ~ op ~ "y;");
        if (result.f.isNaN) {
            result.i &= Number.exp_mask | Number.mant_mask;
        }
        return result.f;
    }

    T min(T)(T x, T y) if (isFloatingPoint!T) {
        if (x.isNaN || y.isNaN) {
            alias Number = Float!T;
            Number result;

            if (x.isNaN) {
                result.f = x;
            }
            if (y.isNaN) {
                Float!T y_map;
                y_map.f = y;
                result.i |= y_map.i;
            }
            result.i &= (Number.U(1) << (T.sizeof * 8 - 1)) - 1;
            return result.f;
        }
        if ((x == T(0)) && (y == T(0))) {
            return signbit(x) ? x : y;
        }
        return (x < y) ? x : y;
    }

    T max(T)(T x, T y) if (isFloatingPoint!T) {
        if (x.isNaN || y.isNaN) {
            alias Number = Float!T;
            Number result;

            if (x.isNaN) {
                result.f = x;
            }
            if (y.isNaN) {
                Number y_map;
                y_map.f = y;
                result.i |= y_map.i;
            }
            result.i &= (Number.U(1) << (T.sizeof * 8 - 1)) - 1;
            return result.f;
        }
        if ((x == T(0)) && (y == T(0))) {
            return signbit(y) ? x : y;
        }
        return (x > y) ? x : y;
    }

    T sqrt(T)(T x) => func!"sqrt"(x);
    T floor(T)(T x) => func!"floor"(x);
    T ceil(T)(T x) => func!"ceil"(x);
    T trunc(T)(T x) => func!"trunc"(x);
    T nearest(T)(T x) => func!"nearbyint"(x);

    T func(string name, T)(T x) @trusted if (isFloatingPoint!T) {
        alias Number = Float!T;
        Number result;
        if (x.isNaN) {
            result.f = x;
            if (x.signbit) {
                return -result.f;
            }
        }
        static if (is(T == float)) {
            mixin("result.f=cmath." ~ name ~ "f(x);");
        }
        else {
            mixin("result.f=cmath." ~ name ~ "(x);");
        }
        if (result.f.isNaN && signbit(result.f)) {
            result.i &= (Number.U(1) << (T.sizeof * 8 - 1)) - 1;
        }
        return result.f;
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
                    enum max_int = 0x1p+32F - 1.0F;
                    enum min_int = 0x0p+0F;
                }
            }
            else {
                static if (isSigned!T) {
                    enum max_int = 0x1p+63F - 1.0F;
                    enum min_int = -0x1p+63F;
                }
                else {
                    enum max_int = 0x1p+64F - 1.0F;
                    enum min_int = 0x1p+0F;
                }
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

double promote(float x) @trusted {
    import std.math : isNaN;
    import core.stdc.stdio;

    if (x.isNaN) {
        Float!float x_nan, y;
        x_nan.f = x;
        y.f = snan!float(0x7fc0_0000);
        Float!double result;
        //result.i = long(x_nan.i) << 13+8+8;
        result.i = long(x_nan.i) << 29;
        result.i |= result.exp_mask;

        printf("x=%08x result=%016lx %08x\n", x_nan.i, result.i, y.i);
        //result.i |= result.exp_mask;
        if (signbit(x)) {
            return -result.f;
        }
        return result.f;
    }
    return cast(double) x;
}

float demote(double x) {
    import std.math : isNaN, signbit;
    import std.stdio;

    if (x.isNaN) {
        Float!double snan;
        snan.f = x;
        Float!float result;
        result.i = cast(int)(snan.i >> 29) & 0x7FFF_FFFF;
        writefln("result %a %08x %s", result.f, result.i, result.f.signbit);
        return result.f;
    }
    return cast(float) x;
}
