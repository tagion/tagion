module foundation.math;

public import core.stdc.math;
import cmath = core.stdc.math;
import std.math : isNaN, signbit;
import std.traits;

@safe:
@nogc nothrow:

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

    wasm.Float!float result;
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
    wasm.Float!float result;

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
    return (x<y)?x:y;
}


T max(T)(T x, T y) @trusted if (isFloatingPoint!T) {
    import wasm = foundation.wasm;
    if (x.isNaN || y.isNaN) {
    wasm.Float!float result;

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
    return (x>y)?x:y;
}

T sqrt(T)(T x) => func!"sqrt"(x);

T func(string name, T)(T x) @trusted if (isFloatingPoint!T) {
    import wasm = foundation.wasm;
    wasm.Float!float result;
    if (x.isNaN) {

        if (x.isNaN) {
            result.f = x;
        }
        result.i &= (wasm.FloatAsInt!T(1) << (T.sizeof * 8 - 1)) - 1;
        return result.f;
    }
    static if (is(T == float)) {
    mixin("result.f=cmath."~name~"f(x);");
    }
    else {
        mixin("result.f=cmath."~name~"(x);");
    }
    if (result.f.isNaN && signbit(result.f)) {
        result.i &= (wasm.FloatAsInt!T(1) << (T.sizeof * 8 - 1)) - 1;
    }
    return result.f;
}

