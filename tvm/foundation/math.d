module foundation.math;

public import core.stdc.math;
import cmath=core.stdc.math;
import std.math : isNaN,signbit;
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

T add(T)(T x, T y) @trusted if (isFloatingPoint!T) {
    if (isNaN(x) || isNaN(y)) {
        import wasm=foundation.wasm;
        import core.stdc.stdio;
        wasm.b32 x_b32, y_b32, nan_new, nan_raw;
        nan_raw.f32=float.nan;
        x_b32.f32=x;
        y_b32.f32=y;
        printf("x_b32=%08x y_b32=%08x\n", x_b32.i32, y_b32.i32);
        printf("arith bit %08x\n", (x_b32.i32 | y_b32.i32) & 0x20_0000);
        printf("nan=%08x %08x\n", nan_new.i32, uint(1) << 22);
        nan_new.f32 = wasm.snan(nan_raw.i32 | ((x_b32.i32 | y_b32.i32)) );
        printf("nan_new=%08x\n", nan_new.i32);

        //return wasm.snan(0x20_0000);
        return T.nan;
    }
    return x + y;
}


