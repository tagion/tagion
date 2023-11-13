module tagion.betterC.funnel.TagionCurrency;

import std.algorithm.searching : canFind;
import std.format;
import std.range : only;
import std.traits : isFloatingPoint, isIntegral, isNumeric;

// import std.array : join;
// import std.conv : to;
import tagion.betterC.hibon.Document;
import tagion.betterC.hibon.HiBON;
import tagion.betterC.wallet.WalletRecords;

// import tagion.hibon.HiBONRecord : HiBONRecord, Label, RecordType;

@safe
TagionCurrency TGN(T)(T x) pure if (isNumeric!T) {
    return TagionCurrency(cast(double) x);
}

@trusted
struct TagionCurrency {
    enum long AXION_UNIT = 1_000_000_000;
    enum long AXION_MAX = 1_000_000_000 * AXION_UNIT;
    enum UNIT = "TGN";

    protected {
        @Label("$v") long _axions;
    }

    long get_axions() pure const {
        return _axions;
    }

    this(T)(const T axions) pure if (isIntegral!T) {
        _axions = axions;
    }

    this(T)(T tagions) pure if (isFloatingPoint!T) {
        _axions = cast(long)(tagions * AXION_UNIT);
    }

    inout(HiBONT) toHiBON() inout {
        auto hibon = HiBON();
        hibon["$v"] = _axions;
        return cast(inout) hibon;
    }

    const(Document) toDoc() {
        auto doc = Document(toHiBON.serialize);
        return cast(const) doc;
    }

    this(Document doc) {
        _axions = doc["$v"].get!long;
    }

    bool verify() const pure nothrow {
        return _axions > -AXION_MAX && _axions < AXION_MAX;
    }

    TagionCurrency opBinary(string OP)(const TagionCurrency rhs) const pure
    if (
        ["+", "-", "%"].canFind(OP)) {
        enum code = format(q{return TagionCurrency(_axions %1$s rhs._axions);}, OP);
        mixin(code);
    }

    TagionCurrency opBinary(string OP, T)(T rhs) const pure
    if (isIntegral!T && (["+", "-", "*", "%", "/"].canFind(OP))) {
        enum code = format(q{return TagionCurrency(_axions %s rhs);}, OP);
        mixin(code);
    }

    TagionCurrency opBinaryRight(string OP, T)(T left) const pure
    if (isIntegral!T && (["+", "-", "*"].canFind(OP))) {
        enum code = format(q{return TagionCurrency(left %s _axions);}, OP);
        mixin(code);
    }

    TagionCurrency opUnary(string OP)() const pure if (OP == "-" || OP == "-") {
        static if (OP == "-") {
            return TagionCurrency(-_axions);
        }
        else {
            return TagionCurrency(_axions);
        }
    }

    void opOpAssign(string OP)(const TagionCurrency rhs) pure
    if (["+", "-", "%"].canFind(OP)) {
        enum code = format(q{_axions %s= rhs._axions;}, OP);
        mixin(code);
    }

    void opOpAssign(string OP, T)(const T rhs) pure
    if (isIntegral!T && (["+", "-", "*", "%", "/"].canFind(OP))) {
        enum code = format(q{_axions %s= rhs;}, OP);
        mixin(code);
    }

    void opOpAssign(string OP, T)(const T rhs) pure
    if (isFloatingPoint!T && (["*", "%", "/"].canFind(OP))) {
        enum code = format(q{_axions %s= rhs;}, OP);
        mixin(code);
    }

    const {

        bool opEquals(const TagionCurrency x) {
            return _axions == x._axions;
        }

        bool opEquals(T)(T x) if (isNumeric!T) {
            return _axions == x;
        }

        int opCmp(const TagionCurrency x) {
            if (_axions < x._axions) {
                return -1;
            }
            else if (_axions > x._axions) {
                return 1;
            }
            return 0;
        }

        int opCmp(T)(T x) if (isNumeric!T) {
            if (_axions < x) {
                return -1;
            }
            else if (_axions > x) {
                return 1;
            }
            return 0;
        }

        long axios() {
            if (_axions < 0) {
                return -(-_axions % AXION_UNIT);
            }
            return _axions % AXION_UNIT;
        }

        long tagions() {
            if (_axions < 0) {
                return -(-_axions / AXION_UNIT);
            }
            return _axions / AXION_UNIT;
        }

        double value() {
            return double(_axions) * AXION_UNIT;
        }
    }

    // static string toTagion(const long axions) pure {
    //     long value = axions;
    //     if (axions < 0) {
    //         value = -value;
    //     }
    //     const sign = (axions < 0) ? "-" : "";
    //     return only(sign, (value / AXION_UNIT).to!string, ".", (value % AXION_UNIT).to!string).join;
    // }

    // string toString() {
    //     return toTagion(_axions);
    // }

    ///
    // unittest {
    //     //import std.stdio;
    //     import std.exception : assertThrown;

    //     // Checks for illegal opBinary operators
    //     static foreach (op; ["*", "/"]) {
    //         {
    //             enum code = format(
    //                         q{
    //                     static assert(!__traits(compiles, 10.TGN %s 12.TGN));
    //                 }, op);
    //             mixin(code);
    //         }
    //     }
    //     // Checks for illegal opBinaryRight operators
    //     static foreach (op; ["/", "%"]) {
    //         {
    //             enum code = format(
    //                         q{
    //                     static assert(!__traits(compiles, 4 %s 12.TGN));
    //                 }, op);
    //             mixin(code);
    //         }
    //     }

    //     // Check for illegal opOpAssign operators
    //     static foreach (op; ["*=", "/="]) {
    //         {
    //             enum code = format!q{
    //             static assert(!__traits(compiles,
    //             ()
    //             {
    //                 TagionCurrency x;
    //                 x %s x;
    //             }));
    //         }(op);
    //             mixin(code);
    //         }
    //     }

    //     { // test of opEqual, opBinary, opBinaryRight, opUnary, opCmp
    //         const x = 11.TGN;
    //         const y = 31.TGN;
    //         assert(x == 11 * AXION_UNIT);
    //         assert(x + y == 42.TGN);
    //         const z = x.opBinary!"+"(31 * AXION_UNIT);
    //         assert(x + (31 * AXION_UNIT) == 42.TGN);
    //         assert(x * 4 == 44.TGN);
    //         assert(x / 4 == 2.75.TGN);
    //         assert(y - x == 20.TGN);
    //         assert(x - y == -20.TGN); // Check opUnary
    //         assert(y - x * 2 == 9.TGN);
    //         assert((x + 0.1.TGN) % 0.25.TGN == 0.1.TGN);
    //         // check opBinaryRight
    //         assert(4 * x == 44.TGN);
    //         assert(4 * AXION_UNIT + x == 15.TGN);
    //         assert(4 * AXION_UNIT - x == -7.TGN);
    //         // test opCmp
    //         assert(x < y);
    //         assert(!(x > y));
    //         const x_same = 11 * AXION_UNIT;
    //         assert(x >= x_same);
    //         assert(x <= x_same);
    //         assert(x - y < -11 * AXION_UNIT);
    //         assert(y - x > 11 * AXION_UNIT);
    //     }

    //     { // test opOpAssign
    //         auto x = 11.TGN;
    //         auto y = 31.TGN;
    //         y += x;
    //         assert(y == 11.TGN + 31.TGN);
    //         y -= 2 * x;
    //         assert(y == 31.TGN - 11.TGN);
    //         x += 5 * AXION_UNIT;
    //         assert(x == 11.TGN + 5.TGN);
    //         x -= 5 * AXION_UNIT;
    //         assert(x == 11.TGN);
    //         x *= 5;
    //         assert(x == 5 * 11.TGN);
    //         x /= 5;
    //         assert(x == 11.TGN);
    //         x += 0.1.TGN;
    //         x %= 0.25.TGN;
    //         assert(x == 0.1.TGN);

    //     }

    //     { // Check over and underflow
    //         import tagion.script.ScriptException : ScriptException;

    //         const very_rich = (AXION_MAX / AXION_UNIT - 1).TGN;
    //         assertThrown!ScriptException(very_rich + 2.TGN);
    //         const very_poor = (-AXION_MAX / AXION_UNIT + 1).TGN;
    //         assertThrown!ScriptException(very_poor - 2.TGN);

    //     }
    // }
}
