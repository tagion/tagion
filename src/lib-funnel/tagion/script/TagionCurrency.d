module tagion.script.TagionCurrency;

import std.format;
import std.traits : isIntegral, isNumeric, isFloatingPoint;
import std.algorithm.searching : canFind;
import std.exception : assumeWontThrow;
import std.range : only;
import std.array : join;
import std.conv : to;

import tagion.hibon.HiBONRecord : HiBONRecord, label, recordType;

@safe
TagionCurrency TGN(T)(T x) pure if (isNumeric!T) {
    return TagionCurrency(cast(double) x);
}

alias TagionCurrency = Currency!("TGN", 1_000_000_000, 1_000_000_000);

@safe
struct Currency(string _UNIT, long _BASE_UNIT = 1_000_000_000, long UNIT_MAX = 1_000_000_000) {
    static assert(_BASE_UNIT > 0, "Base unit must be positive");
    static assert(UNIT_MAX > 0, "Max unit mist be positive");
    enum long BASE_UNIT = _BASE_UNIT;
    enum long UNIT_MAX = 1_000_000_000 * BASE_UNIT;
    enum UNIT = _UNIT;

    protected {
        @label("$v") long _units;
    }

    mixin HiBONRecord!(
            q{
            this(T)(T tagions) pure if (isFloatingPoint!T) {
                scope(exit) {
                    check_range;
                }
                _units = cast(long)(tagions * BASE_UNIT);
            }

            this(T)(const T axions) pure if (isIntegral!T) {
                scope(exit) {
                    check_range;
                }
                _units = axions;
            }
        });

    bool verify() const pure nothrow {
        return _units > -UNIT_MAX && _units < UNIT_MAX;
    }

    void check_range() const pure {
        import tagion.script.ScriptException : scriptCheck = check;

        scriptCheck(_units > -UNIT_MAX && _units < UNIT_MAX,
                format("Value out of range [%s:%s] value is %s",
                toTagion(-UNIT_MAX),
                toTagion(UNIT_MAX),
                toTagion(_units)));
    }

    TagionCurrency opBinary(string OP)(const TagionCurrency rhs) const pure
    if (
        ["+", "-", "%"].canFind(OP)) {
        enum code = format(q{return TagionCurrency(_units %1$s rhs._units);}, OP);
        mixin(code);
    }

    TagionCurrency opBinary(string OP, T)(T rhs) const pure
    if (isIntegral!T && (["+", "-", "*", "%", "/"].canFind(OP))) {
        enum code = format(q{return TagionCurrency(_units %s rhs);}, OP);
        mixin(code);
    }

    TagionCurrency opBinaryRight(string OP, T)(T left) const pure
    if (isIntegral!T && (["+", "-", "*"].canFind(OP))) {
        enum code = format(q{return TagionCurrency(left %s _units);}, OP);
        mixin(code);
    }

    TagionCurrency opUnary(string OP)() const pure if (OP == "-" || OP == "-") {
        static if (OP == "-") {
            return TagionCurrency(-_units);
        }
        else {
            return TagionCurrency(_units);
        }
    }

    void opOpAssign(string OP)(const TagionCurrency rhs) pure
    if (["+", "-", "%"].canFind(OP)) {
        scope (exit) {
            check_range;
        }
        enum code = format(q{_units %s= rhs._units;}, OP);
        mixin(code);
    }

    void opOpAssign(string OP, T)(const T rhs) pure
    if (isIntegral!T && (["+", "-", "*", "%", "/"].canFind(OP))) {
        scope (exit) {
            check_range;
        }
        enum code = format(q{_units %s= rhs;}, OP);
        mixin(code);
    }

    void opOpAssign(string OP, T)(const T rhs) pure
    if (isFloatingPoint!T && (["*", "%", "/"].canFind(OP))) {
        scope (exit) {
            check_range;
        }
        enum code = format(q{_units %s= rhs;}, OP);
        mixin(code);
    }

    pure const nothrow @nogc {

        bool opEquals(const TagionCurrency x) {
            return _units == x._units;
        }

        bool opEquals(T)(T x) if (isNumeric!T) {
            import std.math;

            static if (isFloatingPoint!T) {
                return isClose(value, x, 1e-9);
            }
            else {
                return _units == x;
            }
        }

        int opCmp(const TagionCurrency x) {
            if (_units < x._units) {
                return -1;
            }
            else if (_units > x._units) {
                return 1;
            }
            return 0;
        }

        int opCmp(T)(T x) if (isNumeric!T) {
            if (_units < x) {
                return -1;
            }
            else if (_units > x) {
                return 1;
            }
            return 0;
        }

        long axios() {
            if (_units < 0) {
                return -(-_units % BASE_UNIT);
            }
            return _units % BASE_UNIT;
        }

        long tagions() {
            if (_units < 0) {
                return -(-_units / BASE_UNIT);
            }
            return _units / BASE_UNIT;
        }

        double value() {
            return double(_units) / BASE_UNIT;
        }

        T opCast(T)() {
            static if (is(Unqual!T == double)) {
                return value;
            }
            else {
                static assert(0, format("%s casting is not supported", T.stringof));
            }
        }

    }

    static string toTagion(const long axions) pure {
        long value = axions;
        if (axions < 0) {
            value = -value;
        }
        const sign = (axions < 0) ? "-" : "";
        return only(sign, (value / BASE_UNIT).to!string, ".", (value % BASE_UNIT).to!string).join;
    }

    string toString() {
        return toTagion(_units);
    }
}

@safe ///
unittest {
    //import std.stdio;
    import std.exception : assertThrown;

    // Checks for illegal opBinary operators
    static foreach (op; ["*", "/"]) {
        {
            enum code = format(
                        q{
                        static assert(!__traits(compiles, 10.TGN %s 12.TGN));
                    }, op);
            mixin(code);
        }
    }
    // Checks for illegal opBinaryRight operators
    static foreach (op; ["/", "%"]) {
        {
            enum code = format(
                        q{
                        static assert(!__traits(compiles, 4 %s 12.TGN));
                    }, op);
            mixin(code);
        }
    }

    // Check for illegal opOpAssign operators
    static foreach (op; ["*=", "/="]) {
        {
            enum code = format!q{
                static assert(!__traits(compiles,
                ()
                {
                    TagionCurrency x;
                    x %s x;
                }));
            }(op);
            mixin(code);
        }
    }

    { // test of opEqual, opBinary, opBinaryRight, opUnary, opCmp
        const x = 11.TGN;
        const y = 31.TGN;
        assert(x == 11 * TagionCurrency.BASE_UNIT);
        assert(x + y == 42.TGN);
        const z = x.opBinary!"+"(31 * TagionCurrency.BASE_UNIT);
        assert(x + (31 * TagionCurrency.BASE_UNIT) == 42.TGN);
        assert(x * 4 == 44.TGN);
        assert(x / 4 == 2.75.TGN);
        assert(y - x == 20.TGN);
        assert(x - y == -20.TGN); // Check opUnary
        assert(y - x * 2 == 9.TGN);
        assert((x + 0.1.TGN) % 0.25.TGN == 0.1.TGN);
        // check opBinaryRight
        assert(4 * x == 44.TGN);
        assert(4 * TagionCurrency.BASE_UNIT + x == 15.TGN);
        assert(4 * TagionCurrency.BASE_UNIT - x == -7.TGN);
        // test opCmp
        assert(x < y);
        assert(!(x > y));
        const x_same = 11 * TagionCurrency.BASE_UNIT;
        assert(x >= x_same);
        assert(x <= x_same);
        assert(x - y < -11 * TagionCurrency.BASE_UNIT);
        assert(y - x > 11 * TagionCurrency.BASE_UNIT);
    }

    { // test opOpAssign
        auto x = 11.TGN;
        auto y = 31.TGN;
        y += x;
        assert(y == 11.TGN + 31.TGN);
        y -= 2 * x;
        assert(y == 31.TGN - 11.TGN);
        x += 5 * TagionCurrency.BASE_UNIT;
        assert(x == 11.TGN + 5.TGN);
        x -= 5 * TagionCurrency.BASE_UNIT;
        assert(x == 11.TGN);
        x *= 5;
        assert(x == 5 * 11.TGN);
        x /= 5;
        assert(x == 11.TGN);
        x += 0.1.TGN;
        x %= 0.25.TGN;
        assert(x == 0.1.TGN);

    }

    { // Check over and underflow
        import tagion.script.ScriptException : ScriptException;

        const very_rich = (TagionCurrency.UNIT_MAX / TagionCurrency.BASE_UNIT - 1).TGN;
        assertThrown!ScriptException(very_rich + 2.TGN);
        const very_poor = (-TagionCurrency.UNIT_MAX / TagionCurrency.BASE_UNIT + 1).TGN;
        assertThrown!ScriptException(very_poor - 2.TGN);

    }

    { // Check casting to double
        import std.math : isClose;

        const x = 5.465.TGN;
        const x_double = cast(double) x;
        assert(isClose(x_double, 5.465, 1e-9));
        const x_back_tgn = x_double.TGN;
        assert(x_back_tgn == 5.465);
    }
}
