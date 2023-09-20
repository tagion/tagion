module tagion.script.Currency;
import std.algorithm.searching : canFind;

import std.traits : isIntegral, isNumeric, isFloatingPoint;
import std.range;
import std.format;
import std.traits;
import std.algorithm;
import tagion.hibon.HiBONRecord : HiBONRecord, label, recordType;
import tagion.script.ScriptException : ScriptException, scriptCheck = check;

@safe
const(V) totalAmount(R, V = ElementType!R)(R r) if (isInputRange!R && isCurrency!V) {
    scriptCheck(r.all!(v => v.units >= 0), format("Negative currency unit %s ", V.UNIT));
    return r.sum;
}

@safe
template isCurrency(alias T) {
    enum isCurrency = __traits(hasMember, T, "units") && is(typeof(T.units()) == long);
}

version (unittest) {
    alias MyCurrency = Currency!"My";
}
@safe
static unittest {
    static assert(isCurrency!MyCurrency);
}

@safe
unittest {
    import std.exception;

    auto list = [MyCurrency(12.0), MyCurrency(120.0), MyCurrency(1300.0)];
    import std.stdio;

    assert(list.totalAmount == MyCurrency(1432.0));
    assertThrown!ScriptException((list ~ MyCurrency(-1.3)).totalAmount);

}

@safe
struct Currency(string _UNIT, long _BASE_UNIT = 1_000_000_000, long MAX_VALUE_IN_BASE_UNITS = 1_000_000_000) {
    static assert(_BASE_UNIT > 0, "Base unit must be positive");
    static assert(UNIT_MAX > 0, "Max unit mist be positive");
    enum long BASE_UNIT = _BASE_UNIT;
    enum long UNIT_MAX = MAX_VALUE_IN_BASE_UNITS * BASE_UNIT;
    enum UNIT = _UNIT;
    //    enum type_name = _UNIT;
    protected {
        @label("$") long _units;
    }

    mixin HiBONRecord!(
            q{
            this(T)(T whole) pure if (isFloatingPoint!T) {
                scope(exit) {
                    check_range;
                }
                _units = cast(long)(whole * BASE_UNIT);
            }

            this(T)(const T units) pure if (isIntegral!T) {
                scope(exit) {
                    check_range;
                }
                _units = units;
            }
        });

    bool verify() const pure nothrow {
        return _units > -UNIT_MAX && _units < UNIT_MAX;
    }

    void check_range() const pure {

        scriptCheck(_units > -UNIT_MAX && _units < UNIT_MAX,
                format("Value out of range [%s:%s] value is %s",
                toValue(-UNIT_MAX),
                toValue(UNIT_MAX),
                toValue(_units)));
    }

    Currency opBinary(string OP)(const Currency rhs) const pure
    if (
        ["+", "-", "%"].canFind(OP)) {
        enum code = format(q{return Currency(_units %1$s rhs._units);}, OP);
        mixin(code);
    }

    Currency opBinary(string OP, T)(T rhs) const pure
    if (isIntegral!T && (["+", "-", "*", "%", "/"].canFind(OP))) {
        enum code = format(q{return Currency(_units %s rhs);}, OP);
        mixin(code);
    }

    Currency opBinaryRight(string OP, T)(T left) const pure
    if (isIntegral!T && (["+", "-", "*"].canFind(OP))) {
        enum code = format(q{return Currency(left %s _units);}, OP);
        mixin(code);
    }

    Currency opUnary(string OP)() const pure if (OP == "-" || OP == "-") {
        static if (OP == "-") {
            return Currency(-_units);
        }
        else {
            return Currency(_units);
        }
    }

    void opOpAssign(string OP)(const Currency rhs) pure
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

        bool opEquals(const Currency x) {
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

        int opCmp(const Currency x) {
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

        long units() {
            return _units;
        }

        long axios() {
            if (_units < 0) {
                return -(-_units % BASE_UNIT);
            }
            return _units % BASE_UNIT;
        }

        long whole() {
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

    static string toValue(const long units) pure {
        long value = units;
        if (units < 0) {
            value = -value;
        }
        const sign = (units < 0) ? "-" : "";
        return only(sign, (value / BASE_UNIT).to!string, ".", (value % BASE_UNIT).to!string).join;
    }

    string toString() {
        return toValue(_units);
    }
}
