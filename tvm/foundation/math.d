module foundation.math;

public import core.stdc.math;
import cmath = core.stdc.math;
import std.math : isNaN, signbit;
import std.traits;
import foundation.error;

void print_debug(F)(const F result, const F x, const F y, const F expected, string msg) {
    import std.stdio;
    import std.string;
    import std.conv;

    alias Number = Float!F;
    Number _result, _x, _y, _expected;
    _result.f = result;
    _x.f = x;
    _y.f = y;
    _expected.f = expected;
    writefln("%s result=%0#x x=%0#x y=%0#x expected=%0#x"
            .replace("#", (F.sizeof * 2).to!string),
            msg,
            _result.i, _x.i, _y.i, _expected.i);
}

void print_debug(F, I)(const F result, const I x,  const F expected, string msg) {
    import std.stdio;
    import std.string;
    import std.conv;

    alias Number = Float!F;
    Number _result,   _expected;
    _result.f = result;
    _expected.f = expected;
    writefln("%s result=%0#x x=%0#x expected=%0#x"
            .replace("#", (F.sizeof * 2).to!string),
            msg,
            _result.i, x,  _expected.i);
}

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
        enum sign_mask = (U(1) << (F.sizeof * 8 - 1));
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
                    result.i);
            return (result.i & result.mant_mask) == result.canonical_mask;
        }
        return false;
    }

    unittest {
        float x = float.nan;
        assert(x.isCanonical);
    }

    /**
     * |       x        |      y        | result         |
     * | -------------- | ------------- | -------------- | 
     * | nan:canonical  | number        | nan:canonical  |
     * | number         | nan:canonical | nan:canonical  | 
     * | nan:arithmetic | dofn't care   | nan:arithmetic | 
     * | don't care     | nan:arithmetic| nan:arithmetic | 
     * else return false
     

     * Params:
     *   x = 
     *   y = 
     *   result = 
     * Returns: 
     */
    bool isNaNs(F)(F x, F y, ref F result) if (isFloatingPoint!F) {
        if (x.isNaN || y.isNaN) {
            alias Number = Float!F;
            Number _result;
            scope (exit) {
                _result.i &= ~(Number.sign_mask);
                result = _result.f;
            }
            if (x.isNaN && !x.isCanonical) {
                _result.f = x;
                return true;
            }
            if (y.isNaN && !y.isCanonical) {
                _result.f = y;
                return true;
            }
            _result.f = F.nan;
            _result.i |= Number.canonical_mask;
            return true;
        }
        return false;
    }

    bool isNaNs(F)(ref F x) if(isFloatingPoint!F) {
        if (x.isNaN) {
            alias Number = Float!F;
            Number result;
            scope (exit) {
                result.i &= ~(Number.sign_mask);
                x = result.f;
            }
            if (x.isCanonical) {
                result.f = F.nan;
                result.i |= result.canonical_mask;
            }
            result.f = x;
            return true;
        }
        return false;
    }

    import core.stdc.stdio;

    F snan(F, T)(T x = 0) if (isFloatingPoint!F) {
        if (x & Float!F.mant_mask) {
            Float!F result;
            result.i = (x | result.exp_mask);
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

    F arithmetic(string op, F)(F x, F y) @trusted if (isFloatingPoint!F) {
        F result;
        if (isNaNs(x, y, result)) {
            return result;
        }
        mixin("result=x" ~ op ~ "y;");
        isNaNs(result);
        return result;
    }

    F min(F)(F x, F y) if (isFloatingPoint!F) {
        F result;
        if (!isNaNs(x, y, result)) {
            if ((x == F(0)) && (y == F(0))) {
                return signbit(x) ? x : y;
            }
            result = (x < y) ? x : y;
        }
        return result;
    }

    F max(F)(F x, F y) if (isFloatingPoint!F) {
        F result;
        if (!isNaNs(x, y, result)) {
            if ((x == F(0)) && (y == F(0))) {
                return signbit(y) ? x : y;
            }
            result = (x > y) ? x : y;
        }
        return result;
    }

    T sqrt(T)(T x) => func!"sqrt"(x);
    T floor(T)(T x) => func!"floor"(x);
    T ceil(T)(T x) => func!"ceil"(x);
    T trunc(T)(T x) => func!"trunc"(x);
    T nearest(T)(T x) => func!"nearbyint"(x);

    F func(string name, F)(F x) @trusted if (isFloatingPoint!F) {
        if (isNaNs(x)) {
            return x;
        }
        F result;
        static if (is(T == float)) {
            mixin("result=cmath." ~ name ~ "f(x);");
        }
        else {
            mixin("result=cmath." ~ name ~ "(x);");
        }
        isNaNs(result);
        return result;
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
