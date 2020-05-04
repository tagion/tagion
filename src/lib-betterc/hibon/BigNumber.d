module hibon.BigNumber;

extern(C):
//protected import std.bigint;
//import std.bigint;
//import std.format;
import std.internal.math.biguintnoasm : BigDigit;
//import std.conv : emplace;
// import std.range.primitives;
// import std.traits;
// import std.system : Endian;

//import hibon.HiBONException : check;


/++
 BigNumber used in the HiBON format
 It is a wrapper of the std.bigint
+/
struct BigNumber {
    BigDigit[] data;
    bool sign;
}

version(none) {
    /++
     Returns:
     the BigNumber as BigDigit array
     +/
    @trusted
    const(BigDigit[]) data() const pure nothrow {
        return _data;
    }

    /++
     Returns:
     the sign of the BigNumber
     +/
    @trusted
    bool sign() const pure nothrow {
        return _sign;
    }


    enum {
        ZERO=BigNumber(0), /// BigNumber zero
        ONE=BigNumber(1),  /// BigNumber one
        MINUSONE=BigNumber(-1) /// BigNumber negative one
    }

    /++
     Construct a BigNumber for an integer
     +/
    @trusted
    this(T)(T x) pure nothrow if (isIntegral!T) {
        this.x=BigInt(x);
    }

    /++
     Construct an number for a BigInt
     +/
    @trusted
    this(const(BigInt) x) pure nothrow {
        this.x=x;
    }

    /++
     Construct an number for a BigNumber
     +/
    @trusted
    this(const(BigNumber) big) pure nothrow {
        this.x=big.x;
    }


    /++
     Constructor from a number-string range
     +/
    @trusted
    this(Range)(Range s) if (
        isBidirectionalRange!Range &&
        isSomeChar!(ElementType!Range) &&
        !isInfinite!Range &&
        !isSomeString!Range) {
        this.x=BitInt(s);
    }

    /++
     Construct an BigNumber from a string of numbers
     +/
    @trusted
    this(Range)(Range s) pure if (isSomeString!Range) {
        this.x=BigInt(s);
    }


    /++
     Construct an BigNumber for explicit sign digit number array
     +/
    @trusted
    this(const bool sign, const(BigDigit[]) dig) {
        _sign=sign;
        _data=dig.dup;
    }

    /++
     Binary operator of op
     Params:
     y = is the right side value
     +/
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

    /++
     Assign of the value x
     Params:
     x = value to be assigned
     Returns:
     The assign value as a BigNumber
     +/
    @trusted
    BigNumber opAssign(T)(T x) pure nothrow if (isIntegral!T) {
        this.x=x;
        return this;
    }

    /++
     Returns:
     the result of the unitary operation op
     +/
    @trusted
    BigNumber opUnary(string op)() pure nothrow const {
        return BigNumber(mixin("%sx;",op));
    }

    /++
     Operation assignment of the value y
     Params:
     y = value to be assigned
     Returns:
     The assign value as a BigNumber
     +/

    @trusted
    BigNumber opOpAssign(string op, T)(T y) pure nothrow {
        static if (is(T:const(BigNumber))) {
            enum code=format("this.x %s= y.x;", op);
        }
        else {
            enum code=format("this.x %s= y;", op);
        }
        mixin(code);
        return this;
    }

    /++
     Check the BigNumber has the equal value to y
     Params:
     y = value to be compared
     Returns:
     true if the values are equal
     +/
    @trusted
    bool opEquals()(auto ref const BigNumber y) const pure {
        return x == y.x;
    }

    /// ditto
    @trusted
    bool opEquals(T)(T y) const pure nothrow if (isIntegral!T) {
        return x == y;
    }

    /++
     Compare the BigNumber to y
     Params:
     y = value to be compared
     Returns:
     true if the values are equal
     +/
    @trusted
    int opCmp(ref const BigNumber y) pure nothrow const {
        return x.opCmp(y.x);
    }

    /// ditto
    @trusted
    int opCmp(T)(T y) pure nothrow const if (isIntegral!T) {
        return x.opCmp(x);
    }

    /// ditto
    @trusted
    int opCmp(T:BigNumber)(const T y) pure nothrow const {
        return x.opCmp(y.x);
    }

    /// cast BigNumber to a bool
    @trusted
    T opCast(T:bool)() pure nothrow const {
        return x.opCast!bool;
    }

    /// cast BigNumber to a type T
    @trusted
    T opCast(T:ulong)() pure const {
        return cast(T)x;
    }

    @trusted
    @property size_t ulongLength() const pure nothrow {
        return x.ulongLength;
    }

    /++
     Converts to type T
     +/
    @trusted
    T convert(T)() const if (isIntegral!T) {
        import std.conv : to;
        .check((x>=T.min) && (x<=T.max),
            format("Coversion range violation for type %s, value %s is outside the [%d..%d]",
                T.stringof, x, T.min, T.max));
        return x.to!T;
    }

    /++
     Coverts to a number string as a format
     +/
    @trusted
    void toString(scope void delegate(const (char)[]) sink, string formatString) const {
        return x.toString(sink, formatString);
    }

    /// ditto
    @trusted
    void toString(scope void delegate(const(char)[]) sink, const ref FormatSpec!char f) const {
        return x.toString(sink, f);
    }


    /++
     Coverts to a hexa-decimal number as a string as
     +/
    @trusted
    string toHex() const {
        return x.toHex;
    }

    /++
     Coverts to a decimal number as a string as
     +/
    @trusted
    string toDecimalString() const pure nothrow {
        return x.toDecimalString;
    }

}
