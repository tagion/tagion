module foundation.error;

@safe:
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

import std.traits : isBasicType;

template is_equal(T) {
    static if (isBasicType!T) {
        bool is_equal(T a, b) pure nothrow {
            return a is b;
        }
    }
    else {
        bool is_equal(T)(T a, b) pure nothrow {
            static foreach (i; T.length) {
                if (a[i]!is b[i]) {
                    return false;
                }
            }
            return true;
        }
    }
}
