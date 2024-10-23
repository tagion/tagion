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

T add(T)(T x, T y) if (isFloatingPoint!T) {
    if (isNaN(x) || isNaN(y)) {
        return T.nan;
    }
    return x + y;
}


