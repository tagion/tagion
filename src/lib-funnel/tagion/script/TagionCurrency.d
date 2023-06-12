module tagion.script.TagionCurrency;

import std.format;
import std.traits : isNumeric;

//import std.algorithm.searching : canFind;
import std.exception : assumeWontThrow;

//import std.range : only;
//import std.array : join;
//import std.conv : to;

//import tagion.hibon.HiBONRecord : HiBONRecord, label, recordType;
import tagion.script.Currency;

@safe
TagionCurrency TGN(T)(T x) pure if (isNumeric!T) {
    return TagionCurrency(cast(double) x);
}

alias TagionCurrency = Currency!("TGN", 1_000_000_000, 1_000_000_000);
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
