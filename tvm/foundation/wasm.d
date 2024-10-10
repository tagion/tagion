module foundation.wasm;

import core.bitop : bsf, bsr;
public import core.bitop : popcnt;
import std.traits;

@safe:

nothrow {
    T clz(T)(T val) if (isIntegral!T) {
        if (val == 0) {
            return T.sizeof * 8;
        }
        return T(T.sizeof*8-1) - T(bsr(val));
    }

    T ctz(T)(T val) if (isIntegral!T) {
        if (val == 0) {
            return T.sizeof * 8;
        }
        return bsf(val);
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
        if (x == T.min && y == T(-1)) return T(0);
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
    return (x < y)?x:y;
}

T fmax(T)(T x, T y) if (isFloatingPoint!T) {
    import std.math : isNaN;
    if (isNaN(x) || isNaN(y)) {
        return T.nan;
    }
    return (x > y)?x:y;
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
