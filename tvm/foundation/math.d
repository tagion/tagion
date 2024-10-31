module foundation.math;

public import core.stdc.math;
import cmath = core.stdc.math;
import std.math : isNaN, signbit;
import std.traits;
import foundation.error;

@safe:
nothrow  @nogc {
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

    F snan(F, T)(T x) if (isFloatingPoint!F) {
        Float!F result;
        result.f = F.nan;
        result.i |= x;
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
                return x is y;
            }
        }
        return x == y;
    }

    T add(T)(T x, T y) => arithmetic!("+")(x, y);
    T sub(T)(T x, T y) => arithmetic!("-")(x, y);
    T mul(T)(T x, T y) => arithmetic!("*")(x, y);
    T div(T)(T x, T y) => arithmetic!("/")(x, y);

    T arithmetic(string op, T)(T x, T y) @trusted if (isFloatingPoint!T) {
        import wasm = foundation.wasm;

        wasm.Float!T result;
        if (x.isNaN || y.isNaN) {
            import core.stdc.stdio;

            if (x.isNaN) {
                result.f = x;
            }
            if (y.isNaN) {
                wasm.Float!T y_map;
                y_map.f = y;

                result.i |= y_map.i;

            }
        }
        else {
            mixin("result.f=x" ~ op ~ "y;");
        }
        if (result.f.isNaN && signbit(result.f)) {
            result.i &= (wasm.FloatAsInt!T(1) << (T.sizeof * 8 - 1)) - 1;
        }
        return result.f;
    }

    T min(T)(T x, T y) @trusted if (isFloatingPoint!T) {
        import wasm = foundation.wasm;

        if (x.isNaN || y.isNaN) {
            wasm.Float!T result;

            if (x.isNaN) {
                result.f = x;
            }
            if (y.isNaN) {
                wasm.Float!T y_map;
                y_map.f = y;
                result.i |= y_map.i;
            }
            result.i &= (wasm.FloatAsInt!T(1) << (T.sizeof * 8 - 1)) - 1;
            return result.f;
        }
        return (x < y) ? x : y;
    }

    T max(T)(T x, T y) @trusted if (isFloatingPoint!T) {
        import wasm = foundation.wasm;

        if (x.isNaN || y.isNaN) {
            wasm.Float!T result;

            if (x.isNaN) {
                result.f = x;
            }
            if (y.isNaN) {
                wasm.Float!T y_map;
                y_map.f = y;
                result.i |= y_map.i;
            }
            result.i &= (wasm.FloatAsInt!T(1) << (T.sizeof * 8 - 1)) - 1;
            return result.f;
        }
        return (x > y) ? x : y;
    }

    T sqrt(T)(T x) => func!"sqrt"(x);
    T floor(T)(T x) => func!"floor"(x);
    T ceil(T)(T x) => func!"ceil"(x);
    T trunc(T)(T x) => func!"trunc"(x);
    T nearest(T)(T x) => func!"nearbyint"(x);

    T func(string name, T)(T x) @trusted if (isFloatingPoint!T) {
        import wasm = foundation.wasm;

        wasm.Float!T result;
        if (x.isNaN) {

            if (x.isNaN) {
                result.f = x;
            }
            result.i &= (wasm.FloatAsInt!T(1) << (T.sizeof * 8 - 1)) - 1;
            return result.f;
        }
        static if (is(T == float)) {
            mixin("result.f=cmath." ~ name ~ "f(x);");
        }
        else {
            mixin("result.f=cmath." ~ name ~ "(x);");
        }
        if (result.f.isNaN && signbit(result.f)) {
            result.i &= (wasm.FloatAsInt!T(1) << (T.sizeof * 8 - 1)) - 1;
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

double promote(float x) {
    import std.math : isNaN;

    if (x.isNaN) {
        Float!double snan;
        snan.f = x;
        return snan.f;
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
        result.i = cast(int)((snan.i & 0xfff8_0000_0000_0000L) >> 29) & 0x7FFF_FFFF;
        writefln("result %a %08x %s", result.f, result.i, result.f.signbit);
        return result.f;
    }
    return cast(float) x;
}
