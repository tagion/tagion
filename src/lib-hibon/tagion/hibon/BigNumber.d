module tagion.hibon.BigNumber;

protected import std.bigint;
//import std.bigint;
import std.format;
import std.internal.math.biguintnoasm : BigDigit;
//import std.conv : emplace;
import std.range.primitives;
import std.traits;
import std.system : Endian;

import tagion.hibon.HiBONException : check;
import tagion.hibon.BigNumber;

@safe
struct BigNumber {
    private union {
        BigInt x;
        struct {
            BigDigit[] _data;
            bool _sign;
        }
    }


    @trusted
    const(BigDigit[]) data() const pure nothrow {
        return _data;
    }

    @trusted
    bool sign() const pure nothrow {
        return _sign;
    }

    enum ZERO=BigNumber(0);
    enum ONE=BigNumber(1);
    enum MINUSONE=BigNumber(-1);

    // struct EmplaceBigInt {
    //     BigDigit[] data;
    //     bool sign;
    // }
    @trusted
    this(T)(T x) pure nothrow if (isIntegral!T) {
        this.x=BigInt(x);
    }

    @trusted
    this(const(BigInt) x) pure nothrow {
        this.x=x;
    }

    @trusted
    this(const(BigNumber) big) pure nothrow {
        this.x=big.x;
    }



    @trusted
    this(Range)(Range s) if (
        isBidirectionalRange!Range &&
        isSomeChar!(ElementType!Range) &&
        !isInfinite!Range &&
        !isSomeString!Range) {
        this.x=BitInt(s);
    }

    @trusted
    this(Range)(Range s) pure if (isSomeString!Range) {
        this.x=BigInt(s);
    }


    // this(Range)(Range s) if (is(Range:immutable(ubyte[]))) {
    //     this.x=BigInt(x);
    // }

    // @trusted
    // this(immutable(ubyte[]) data) {
    //     assert(
    //         (data.length % BigDigit.sizeof) is bool.sizeof &&
    //         (data.length > BigDigit.sizeof),
    //         format("Size of byte stream does not match the Number size (size=%d)", data.length));
    //     this._data=cast(BigDigit[])(data)[0..data.length/BigDigit.sizeof].dup;
    //     this._sign=(data[$-1] !is 0);
    // }

    // @trusted
    // this(immutable(ubyte[]) data) const {
    //     assert(
    //         (data.length % BigDigit.sizeof) is bool.sizeof &&
    //         (data.length > BigDigit.sizeof),
    //         format("Size of byte stream does not match the Number size (size=%d)", data.length));
    //     this._data=cast(BigDigit[])(data)[0..data.length/BigDigit.sizeof].dup;
    //     this._sign=(data[$-1] !is 0);
    // }

    @trusted
    this(const bool sign, const(BigDigit[]) dig) {
        _sign=sign;
        _data=dig.dup;
    }

    // @trusted
    // this(const bool sign, const(BigDigit[]) dig) {
    //     _sign=sign;
    //     _data=dig.dup;
    // }

    @trusted
    BigNumber opBinary(string op, T)(T y) pure nothrow const {
        static if (is(T:const(BigNumber))) {
            enum code=format("auto result=x %s y.x;", op);
        }
        else {
            enum code=format("auto result=x %s y;", op);
        }
        mixin(code);
        return BigNumber(result);
    }

    @trusted
    BigNumber opAssign(T)(T x) pure nothrow if (isIntegral!T) {
        this.x=x;
        return this;
    }

    @trusted
    BigNumber opUnary(string op)() pure nothrow const {
        return BigNumber(mixin("%sx;",op));
    }

    @trusted
    BigNumber opOpAssign(string op, T)(T y) pure nothrow {
        static if (is(T:const(BigNumber))) {
            enum code=format("auto result=x %s y.x;", op);
        }
        else {
            enum code=format("auto result=x %s y;", op);
        }
        mixin(code);
        return BigNumber(result);
    }

    @trusted
    bool opEquals()(auto ref const BigNumber y) const pure {
        return x == y.x;
    }

    @trusted
    bool opEquals(T)(T y) const pure nothrow if (isIntegral!T) {
        return x == y;
    }

    @trusted
    int opCmp(ref const BigNumber y) pure nothrow const {
        return x.opCmp(y.x);
    }

    @trusted
    int opCmp(T)(T y) pure nothrow const if (isIntegral!T) {
        return x.opCmp(x);
    }

    @trusted
    int opCmp(T:BigNumber)(const T y) pure nothrow const {
        return x.opCmp(y.x);
    }

    @trusted
    T opCast(T:bool)() pure nothrow const {
        return x.opCast!bool;
    }

    @trusted
    T opCast(T:ulong)() pure const {
        return cast(T)x;
    }

    @trusted
    @property size_t ulongLength() const pure nothrow {
        return x.ulongLength;
    }

    @trusted
    T convert(T)() const if (isIntegral!T) {
        import std.conv : to;
        .check((x>=T.min) && (x<=T.max),
            format("Coversion range violation for type %s, value %s is outside the [%d..%d]",
                T.stringof, x, T.min, T.max));
        return x.to!T;
    }

    @trusted
    void toString(scope void delegate(const (char)[]) sink, string formatString) const {
        return x.toString(sink, formatString);
    }

    @trusted
    void toString(scope void delegate(const(char)[]) sink, const ref FormatSpec!char f) const {
        return x.toString(sink, f);
    }

    @trusted
    string toHex() const {
        return x.toHex;
    }

    @trusted
    string toDecimalString() const pure nothrow {
        return x.toDecimalString;
    }
// size_t toHash() const @safe nothrow {
    //     return x.toHash;
    // }


}
