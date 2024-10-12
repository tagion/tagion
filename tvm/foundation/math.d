module foundation.math;

public import core.stdc.math;
import cmath=core.stdc.math;
import std.math : isNaN,signbit;
@safe:
@nogc nothrow:

union b32 {
    int i32;
    float f32;
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
    
