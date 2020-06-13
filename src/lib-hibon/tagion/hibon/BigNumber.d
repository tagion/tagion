module tagion.hibon.BigNumber;

protected import std.bigint;
//import std.bigint;
import std.format;
import std.internal.math.biguintnoasm : BigDigit;
//import std.conv : emplace;
import std.range.primitives;
import std.traits;
import std.system : Endian;
import std.base64;
import std.exception : assumeUnique;

import std.stdio;

import tagion.hibon.HiBONException : check;
import tagion.hibon.BigNumber;


/++
 BigNumber used in the HiBON format
 It is a wrapper of the std.bigint
 +/
@safe
struct BigNumber {

    private union {
        BigInt x;
        struct {
            static assert(BigDigit.sizeof == uint.sizeof);
            uint[] _data;
            bool _sign;
        }
    }


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
    @trusted this(T)(T x) pure nothrow if (isIntegral!T) {
        this.x=BigInt(x);
    }

    /++
     Construct an number for a BigInt
     +/
    @trusted this(const(BigInt) x) pure nothrow {
        this.x=x;
    }

    /++
     Construct an number for a BigNumber
     +/
    @trusted this(const(BigNumber) big) pure nothrow {
        this.x=big.x;
    }

    @trusted protected this(BigDigit[] data, const bool sign) pure nothrow {
        this._data=data;
        this._sign=sign;
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

    @trusted this(const(ubyte[]) buffer) {
        const digits_len=buffer.length / BigDigit.sizeof;
        .check(digits_len > 0, "BigNumber must contain some digits");
        _data=(cast(BigDigit*)(buffer.ptr))[0..digits_len].dup;
        if (buffer.length % BigDigit.sizeof == 0) {
            _sign=false;
        }
        else if (buffer.length % BigDigit.sizeof == 1) {
            .check(buffer[$-1] is 0 || buffer[$-1] is 1,
                format("BigNuber has incorrect sign %d value should 0 or 1", buffer[$-1]));
            _sign=cast(bool)buffer[$-1];
        }
        else {
            .check(0, "Buffer does not have the correct size");
        }
    }
    /++
     Binary operator of op
     Params:
     y = is the right side value
     +/
    @trusted
        BigNumber opBinary(string op, T)(T y) pure nothrow const {
        static if (is(T:const(BigNumber))) {
            enum code=format(q{BigNumber result=x %s y.x;}, op);
        }
        else {
            enum code=format(q{BigNumber result=x %s y;}, op);
        }
        mixin(code);
        return result;
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

    /++
     Coverts to a base64 format
     +/
    @trusted
        immutable(ubyte[]) serialize() const pure nothrow {        immutable digits_size=BigDigit.sizeof*_data.length;
        auto buffer=new ubyte[digits_size+_sign.sizeof];
        buffer[0..digits_size]=cast(ubyte[])_data;
        buffer[$-1]=cast(ubyte)_sign;
        return assumeUnique(buffer);
    }

    TwoComplementRange two_complement() pure const /*nothrow*/ {
        static assert(BigDigit.sizeof is int.sizeof);
        return TwoComplementRange(this);
    }

    @trusted
    void check_minuz_zero() const pure {
        //.check(sign && _data.length is 1 && _data[0] is 0, "The number minus zero is not allowed");
        if (!(sign && _data.length is 1 && _data[0] is 0)) {
            debug writefln("minus zero=%s", sign && _data.length is 1 && _data[0] is 0);
        }
    }

    struct TwoComplementRange {
        protected {
            bool overflow;
            const(BigDigit)[] data;
            long current;
            bool _empty;
        }
        immutable bool sign;

        @disable this();
        @trusted
        this(const BigNumber num) pure /*nothrow*/ {
            sign=num._sign;
            overflow=true;
            data=num._data;
            popFront;
        }

        @property {
            const pure nothrow {
                long front() {
                    return current;
                }
                bool empty() {
                    return _empty;
                }
            }
            void popFront() /+nothrow+/ pure {
                if (data.length) {
                    //debug writefln("data[0]=%d sign=%s", data[0], sign);
                    if (sign) {
                        current=data[0];
                        current=~current;
                        if (overflow) {
                            overflow= (current == -1);
                            current++;


                            //current=~current;



                            // if (overflow) {
                            //     current |= (~0LU) << uint.sizeof*8;
                            // }
                            //debug writefln("             current=%016X %s", current, overflow);
                        }
                        //debug writefln("data[0]=%08X current=%016X", data[0], current);
                    }
                    else {
                        current=data[0];
                    }
                    //debug writefln("\tcurrent=%d front=%d", current, front);
                    data=data[1..$];
                }
                else {
                    _empty=true;
                }
            }
        }
    }

    unittest { // Test of Two complement
        import std.algorithm.comparison : equal;
        writeln("\n\nTWO COMPLEMENT");
        {
            //enum _x=-0x2_0000_0000;
            //num _x=long.min+1;
//            enum _x="-0xab34_1234_6789_abcd_ef01_ab34_1234_6789_abcd_ef01";
            enum _x="-0xAB341234_6789ABCD_EF01AB34_00000000_00000000";
            const(ulong[]) a=[~0x0000_0000UL+1, ~0x00000000UL+1, ~0xEF01AB34UL+1, ~0x6789ABCDUL, ~0xAB341234UL];
            //writefln("a=%s", a);
            //writefln("%016X", _x);
            //enum _x=-1;
            const x=BigNumber(_x);
            write("   ");

            foreach(t; x.two_complement) {
                writef("%d, ", t);
            }
            writeln("");

            foreach(t; x.two_complement) {
                writef("%08X ", t);
            }
            writeln("");
            foreach(c; a) {
                writef("%08X ", c);
            }
            writeln("");

        }

        {
            const x=BigNumber(0);
            assert(equal(x.two_complement, [0]));
        }

        {
            const x=BigNumber(uint.max);
            assert(equal(x.two_complement, [uint.max]));
        }


        {
            const x=BigNumber(-1);
            assert(equal(x.two_complement, [ulong.max]));
        }

        {
            const x=BigNumber(-2);
            assert(equal(x.two_complement, [ulong.max-1]));
        }

        {
            const x=BigNumber(-0x2_0000_0000);
            assert(equal(x.two_complement, [0, 0xFFFFFFFFFFFFFFFE]));
        }

        {
            const x=BigNumber(long.min);
            assert(equal(x.two_complement, [0, 0xFFFFFFFF80000000]));
        }

        {
            const x=BigNumber("0xAB341234_6789ABCD_EF01AB34_12346789_ABCDEF01");
            assert(equal(x.two_complement, [0xABCDEF01, 0x12346789, 0xEF01AB34, 0x6789ABCD, 0xAB341234]));
        }

        {
            const x=BigNumber("-0xAB341234_6789ABCD_EF01AB34_12346789_ABCDEF01");
            const(ulong[]) x_twoc=[~0xABCDEF01UL+1, ~0x12346789UL, ~0xEF01AB34UL, ~0x6789ABCDUL, ~0xAB341234UL];
            assert(equal(x.two_complement, x_twoc));
        }

        {
            const x=BigNumber("-0xAB341234_6789ABCD_EF01AB34_12346789_00000000");
            const(ulong[]) x_twoc=[~0x0000_0000UL+1, ~0x12346789UL+1, ~0xEF01AB34UL, ~0x6789ABCDUL, ~0xAB341234UL];
            assert(equal(x.two_complement, x_twoc));
        }

        {
            const x=BigNumber("-0xAB341234_6789ABCD_EF01AB34_00000000_00000000");
            const(ulong[]) x_twoc=[~0x0000_0000UL+1, ~0x00000000UL+1, ~0xEF01AB34UL+1, ~0x6789ABCDUL, ~0xAB341234UL];
            assert(equal(x.two_complement, x_twoc));
        }

        {
            const x=BigNumber("-0xAB341234_6789ABCD_00000000_00000000_00000000");
            const(ulong[]) x_twoc=[~0x0000_0000UL+1, ~0x00000000UL+1, ~0x00000000UL+1, ~0x6789ABCDUL+1, ~0xAB341234UL];
            assert(equal(x.two_complement, x_twoc));
        }


        {
            const x=BigNumber("-0xAB341234_00000000_00000000_00000000_00000000");
            const(ulong[]) x_twoc=[~0x0000_0000UL+1, ~0x00000000UL+1, ~0x00000000UL+1, ~0x00000000UL+1, ~0xAB341234UL+1];
            assert(equal(x.two_complement, x_twoc));
        }


        writeln("\nTWO COMPLEMENT END\n\n");
    }
    static size_t calc_size(const(ubyte[]) data) pure {
        size_t result;
        foreach(d; data) {
            result++;
            if ((d & 0x80) is 0) {
                return result;
            }
        }
        .check(0, format("Bad LEB128 format for %s", BigNumber.stringof));
        assert(0);
    }

    immutable(ubyte[]) encodeLEB128() const pure {
        check_minuz_zero;
        immutable DATA_SIZE=(BigDigit.sizeof*data.length*8)/7+2;
        enum DIGITS_BIT_SIZE=BigDigit.sizeof*8;
        scope buffer=new ubyte[DATA_SIZE];
        foreach(t; two_complement) {
            debug writefln(">t=%016x", t);
        }
        auto range2c=two_complement;

        long value=range2c.front;
        range2c.popFront;
        uint shift=DIGITS_BIT_SIZE;
        debug writefln("buffer.length=%d", buffer.length);
        foreach(i, ref d; buffer) {

            if ((shift < 7) && (!range2c.empty)) {
                debug writefln("@ %016x shift=%d", (range2c.front << shift) , shift);
                debug writefln("@ %016x %016x", value, int.min);
                value |= (range2c.front << shift);
                shift+=DIGITS_BIT_SIZE;
                range2c.popFront;
            }
            d = value & 0x7F;

            debug writefln("%d %02x %016x %s shift=%d", i, d, value, range2c.empty, shift);
            shift-=7;
            value >>= 7;
            //debug writefln("\t### value=%016x", value);
            if (range2c.empty && (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40)))) {
                return buffer[0..i+1].idup;
            }
            d |= 0x80;
        }
        assert(0);
    }

    size_t calc_size() const pure {
        immutable DATA_SIZE=(BigDigit.sizeof*data.length*8)/7+1;
        enum DIGITS_BIT_SIZE=BigDigit.sizeof*8;
        size_t index;
        auto range2c=two_complement;

        long value=range2c.front;
        range2c.popFront;

        uint shift=DIGITS_BIT_SIZE;
        //debug writefln("DATA_SIZE=%d", DATA_SIZE);
        foreach(i; 0..DATA_SIZE) {
            if ((shift < 7) && (!range2c.empty)) {
                value |= (range2c.front << shift);
                shift+=DIGITS_BIT_SIZE;
                version(none)
                if (range2c.front & int.min) {
                    // Set sign bit
                    value |= (~0L) << shift;
                }
                range2c.popFront;
            }
            scope d = value & 0x7F;
            //debug writefln("SIZE %d %02x %016x %s shift=%d", i, d, value, range2c.empty, shift);
            shift-=7;
            value >>= 7;

            if (range2c.empty && (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40)))) {
                return i+1;
            }
            d |= 0x80;
        }
        assert(0);
    }

    static BigNumber decodeLEB128(const(ubyte[]) data) pure {
        scope values=new uint[data.length/BigDigit.sizeof+1];
        enum DIGITS_BIT_SIZE=uint.sizeof*8;
        ulong result;
        uint shift;
        bool sign;
        size_t index;
        foreach(i, d; data) {
            debug writefln("result=%016x %02x shift=%d", result, d, shift);
            result |= ulong(d & 0x7F) << shift;
            debug writefln("      =%016x", result);
            shift+=7;
            if (shift >= DIGITS_BIT_SIZE) {
                debug writefln("\t## value=%08x", result & uint.max);
                values[index++]=result & uint.max;
                result >>= DIGITS_BIT_SIZE;
                shift-=DIGITS_BIT_SIZE;
            }
            if ((d & 0x80) == 0) {
                if ((d & 0x40) != 0) {
                    result |= (~0L << shift);
                    sign=true;
                }
//                if (index == 0) {
                const v=result & uint.max;
                debug writefln("\t## LAST shift=%d result=%016x v=%08x %d", shift, result, v, index);
                debug writefln("\t## sign=%s (v=-1) = %s %s %s %s %s", sign, cast(int)v == -1, (sign && (cast(int)v == -1)),
                    (v !is 0) && (((sign && (cast(int)v == -1)))),
                    sign?(cast(int)v != -1):(v !is 0),
                    (v != 0) && ((!sign || (cast(int)v != -1))),
                    );
                // if ((index is 0) || (v !is 0)) {
                if ((index is 0) || (sign?(cast(int)v != -1):(v !is 0)) ) {
                    debug writefln("HER!! %d", v);
                    values[index++]=v;
                }
                break;
            }
        }
        auto result_data=values[0..index].dup;
        debug writefln("result_data.length=%d", result_data.length);
        if (sign) {
            // Takes the to complement of the result because BigInt
            // is stored as a unsigned value and a sign
            foreach(ref r; result_data) {
                r=~r;
            }
            bool overflow=true;
            foreach(ref r; result_data) {
                if (overflow) {
                    r++;
                    overflow=(r==0);
                }
                else {
                    break;
                }
            }

        }
        return BigNumber(result_data, sign);
    }

    static BigNumber _decodeLEB128(const(ubyte[]) data) pure {
        scope values=new uint[data.length/BigDigit.sizeof+1];
        enum DIGITS_BIT_SIZE=uint.sizeof*8;
        ulong result;
        uint shift;
        bool sign;
        size_t index;
        foreach(i, d; data) {
            debug writefln("result=%016x %02x shift=%d i=%d", result, d, shift, i);
            result |= ulong(d & 0x7F) << shift;
            debug writefln("      =%016x", result);
            shift+=7;
            if (shift >= DIGITS_BIT_SIZE) {
                debug writefln("\t## value=%08x", result & uint.max);
                values[index++]=result & uint.max;
                result >>= DIGITS_BIT_SIZE;
                shift-=DIGITS_BIT_SIZE;
            }
            if ((d & 0x80) == 0) {
                if ((d & 0x40) != 0) {
                    result |= (~0L << shift);
                    sign=true;
                }
//                if (index == 0) {
                const v=result & uint.max;
                debug writefln("\t## LAST shift=%d result=%016x v=%08x %d", shift, result, v, index);
                debug writefln("\t## sign=%s (v=-1) = %s %s %s %s %s", sign, cast(int)v == -1, (sign && (cast(int)v == -1)),
                    (v !is 0) && (((sign && (cast(int)v == -1)))),
                    sign?(cast(int)v != -1):(v !is 0),
                    (v != 0) && ((!sign || (cast(int)v != -1))),
                    );
                // if ((index is 0) || (v !is 0)) {
                if ((index is 0) || (sign?(cast(int)v != -1):(v !is 0)) ) {
                    debug writefln("HER!! %d", v);
                    values[index++]=v;
                }
                break;
            }
        }
        auto result_data=values[0..index].dup;
        debug writefln("result_data.length=%d sign=%s", result_data.length, sign);
        if (sign) {
            // Takes the to complement of the result because BigInt
            // is stored as a unsigned value and a sign
            foreach(ref r; result_data) {
                r=~r;
            }
            bool overflow=true;
            foreach(ref r; result_data) {
                if (overflow) {
                    r++;
                    overflow=(r==0);
                }
                else {
                    break;
                }
            }

        }
        return BigNumber(result_data, sign);
    }
}


unittest {
    import std.algorithm.comparison : equal;
    import std.stdio;
    import LEB128=tagion.utils.LEB128;
    {
        BigNumber x=0;
        writefln("x.calc_size=%d", x.calc_size);
        writefln("x.encode128=%s", x.encodeLEB128);
        writefln("x.decodeLEB128=%s", x.decodeLEB128([0]));

        assert(x.calc_size is 1);
        assert(x.encodeLEB128 == [0]);
        assert(x.decodeLEB128([0]) == 0);
    }

    void ok(BigNumber x, const(ubyte[]) expected) {
        const encoded=x.encodeLEB128;
        assert(equal(encoded, expected));
        assert(x.calc_size == expected.length);
        assert(BigNumber.calc_size(expected) == expected.length);
        const decoded=BigNumber.decodeLEB128(expected);
//        assert(decoded.size == expected.length);
        writefln("decoded=%s x=%s", decoded, x);
        writefln("decoded=%s._data x=%s._data", decoded._data, x._data);

        assert(decoded == x);
    }

    { // Small positive numbers
        ok(BigNumber(0), [0]);
        ok(BigNumber(1), [1]);
        ok(BigNumber(100), LEB128.encode!long(100));
        ok(BigNumber(1000), LEB128.encode!long(1000));
        ok(BigNumber(int.max), LEB128.encode!long(int.max));
        ok(BigNumber(ulong(uint.max) << 1), LEB128.encode!ulong(ulong(uint.max) << 1));
        ok(BigNumber(long.max), LEB128.encode!long(long.max));
        ok(BigNumber(ulong.max), LEB128.encode!ulong(ulong.max));
    }

    {
        ok(BigNumber(-1), [127]);
        ok(BigNumber(-100), LEB128.encode!long(-100));
        ok(BigNumber(-1000), LEB128.encode!long(-1000));
        ok(BigNumber(int.min), LEB128.encode!long(int.min));
        // ok(BigNumber(long(int.min)*2), LEB128.encode!long(long(int.min)*2));

    }
    {
        writefln("\n\n");
        //enum long_x=0x0000_0003_FFFF_FFFF; //long.max/2;
        enum long_x=long(int.min)*2; //long(int.min)*4L; //ulong.max; //0x0000_0003_FFFF_FFFF; //long.max/2;
        BigNumber x=long_x;
        foreach(t; x.two_complement) {
            writef("%08X ", t & uint.max);
        }
        writeln("");
        writefln("x.encode128  =%s", x.encodeLEB128);
        //writefln("x.calc_size  =%d", x.calc_size);
        writefln("x.calc_size  =%d", x.calc_size);
        const expected=LEB128.encode!long(long_x);
        writefln("LEB128.decode=%s", expected);
        writefln("x           =%s", x.toHex);
        writefln("decodeLEB128=%s", x._decodeLEB128(expected).toHex);
        writefln("x._data=%s", x._data);
        writefln("decodeLEB128._data=%s", BigNumber._decodeLEB128(expected)._data);

        // assert(x.calc_size is 1);
        // assert(x.encodeLEB128 == [1]);
        // assert(x.decodeLEB128([1]) == 1);
    }
}
