module foundation.wasm;

import core.bitop : bsf, bsr;
import std.traits;
public import core.bitop : popcnt;

@safe:

nothrow {
    T clz(T)(T val) if (isIntegral!T) {
        if (val == 0) {
            return T.sizeof * 8;
        }
        return 31 - bsr(val);
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
        error(!(x == T.min && y == -1), "Overflow");
    }
    error(y != 0, "Division with zero");

    return x / y;
}

T rem(T)(T x, T y) if (isIntegral!T) {
    static if (isSigned!T) {
        error(!(x == T.min && y == -1), "Overflow");
    }
    error(y != 0, "Division with zero");

    return x % y;
}

void error(const bool flag, string msg, string file = __FILE__, size_t line = __LINE__) {
    import std.exception;

    if (!flag) {
        throw new Exception(msg, file, line);
    }
}

void assert_trap(E)(lazy E expression, string msg = null, string file = __FILE__, size_t line = __LINE__) {
    import std.exception : assertThrown;

    assertThrown(expression, msg, file, line);
}
