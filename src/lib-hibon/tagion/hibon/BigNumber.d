module tagion.hibon.BigNumber;

protected import std.bigint;

//import std.bigint;
import std.format;
import std.internal.math.biguintnoasm : BigDigit;

//import std.conv : emplace;
import std.range.primitives;
import std.system : Endian;
import std.traits;
import std.typecons : Tuple;
import std.base64;

//import std.stdio;

import tagion.hibon.HiBONException;

/++
 BigNumber used in the HiBON format
 It is a wrapper of the std.bigint
 +/

@safe struct BigNumber {
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
    @trusted @nogc const(BigDigit[]) data() const pure nothrow {
        return _data;
    }

    /++
     Returns:
     the sign of the BigNumber
     +/
    @trusted @nogc bool sign() const pure nothrow {
        return _sign;
    }

    enum {
        ZERO = BigNumber(0), /// BigNumber zero
        ONE = BigNumber(1), /// BigNumber one
        MINUSONE = BigNumber(-1) /// BigNumber negative one
    }

    /++
     Construct a BigNumber for an integer
     +/
    @trusted this(T)(T x) pure nothrow if (isIntegral!T) {
        this.x = BigInt(x);
    }

    /++
     Construct an number for a BigInt
     +/
    @nogc @trusted this(const(BigInt) x) pure nothrow {
        this.x = x;
    }

    /++
     Construct an number for a BigNumber
     +/
    @trusted this(const(BigNumber) big) pure nothrow {
        this.x = big.x;
    }

    @trusted protected this(scope const(BigDigit[]) data, const bool sign) pure nothrow {
        this._data = data.dup;
        this._sign = sign;
    }

    /++
     Constructor from a number-string range
     +/
    @trusted this(Range)(Range s)
            if (isBidirectionalRange!Range && isSomeChar!(ElementType!Range)
                && !isInfinite!Range && !isSomeString!Range) {
        this.x = BitInt(s);
    }

    /++
     Construct an BigNumber from a string of numbers
     +/
    @trusted this(Range)(Range s) pure if (isSomeString!Range) {
        this.x = BigInt(s);
    }

    // /++
    //  Construct an BigNumber for explicit sign digit number array
    //  +/
    // @trusted
    //     this(const bool sign, const(BigDigit[]) dig) {
    //     _sign=sign;
    //     _data=dig.dup;
    // }

    /++
     constructor for BigNumber in LEB128+ formant
     +/
    @trusted this(const(ubyte[]) buffer) pure nothrow {
        auto result = decodeLEB128(buffer);
        _data = result.value._data;
        _sign = result.value._sign;
    }
    /++
     Binary operator of op
     Params:
     y = is the right side value
     +/
    @trusted BigNumber opBinary(string op, T)(T y) pure nothrow const {
        static if (is(T : const(BigNumber))) {
            enum code = format(q{BigNumber result=x %s y.x;}, op);
        }
        else {
            enum code = format(q{BigNumber result=x %s y;}, op);
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
    @trusted BigNumber opAssign(T)(T x) pure nothrow if (isIntegral!T) {
        this.x = x;
        return this;
    }

    /++
     Returns:
     the result of the unitary operation op
     +/
    @trusted BigNumber opUnary(string op)() pure nothrow const
    if (op == "+" || op == "-" || op == "~") {
        enum code = format(q{return BigNumber(%s this.x);}, op);
        mixin(code);
    }

    /++
     Returns:
     the result of the unitary operation op
     +/
    @trusted BigNumber opUnary(string op)() pure nothrow if (op == "++" || op == "--") {
        enum code = format(q{%s this.x;}, op);
        mixin(code);
        return BigNumber(this);
    }

    /++
     Operation assignment of the value y
     Params:
     y = value to be assigned
     Returns:
     The assign value as a BigNumber
     +/
    @trusted BigNumber opOpAssign(string op, T)(T y) pure nothrow {
        static if (is(T : const(BigNumber))) {
            enum code = format("this.x %s= y.x;", op);
        }
        else {
            enum code = format("this.x %s= y;", op);
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
    @trusted @nogc bool opEquals()(auto ref const BigNumber y) const pure {
        return x == y.x;
    }

    /// ditto
    @trusted @nogc bool opEquals(T)(T y) const pure nothrow if (isIntegral!T) {
        return x == y;
    }

    /++
     Compare the BigNumber to y
     Params:
     y = value to be compared
     Returns:
     true if the values are equal
     +/
    @trusted @nogc int opCmp(ref const BigNumber y) pure nothrow const {
        return x.opCmp(y.x);
    }

    /// ditto
    @trusted @nogc int opCmp(T)(T y) pure nothrow const if (isIntegral!T) {
        return x.opCmp(x);
    }

    /// ditto
    @trusted @nogc int opCmp(T : BigNumber)(const T y) pure nothrow const {
        return x.opCmp(y.x);
    }

    /// cast BigNumber to a bool
    @trusted T opCast(T : bool)() pure nothrow const {
        return x.opCast!bool;
    }

    /// cast BigNumber to a type T
    @trusted T opCast(T : ulong)() pure const {
        return cast(T) x;
    }

    @trusted @nogc @property size_t ulongLength() const pure nothrow {
        return x.ulongLength;
    }

    /++
     Converts to type T
     +/
    @trusted T convert(T)() const if (isIntegral!T) {
        import std.conv : to;

        

        .check((x >= T.min) && (x <= T.max),
                format("Conversion range violation for type %s, value %s is outside the [%d..%d]",
                T.stringof, x, T.min, T.max));
        return x.to!T;
    }

    /++
     Coverts to a number string as a format
     +/
    @trusted void toString(scope void delegate(const(char)[]) sink, string formatString) const {
        return x.toString(sink, formatString);
    }

    /// ditto
    @trusted void toString(scope void delegate(const(char)[]) sink, const ref FormatSpec!char f) const {
        return x.toString(sink, f);
    }

    /++
     Coverts to a hexa-decimal number as a string as
     +/
    @trusted string toHex() const {
        return x.toHex;
    }

    /++
     Coverts to a decimal number as a string as
     +/
    @trusted string toDecimalString() const pure nothrow {
        return x.toDecimalString;
    }

    /++
     Converts the BigNumber as a two complement representation
     Returns:
     Range of two complement
     +/
    @nogc TwoComplementRange two_complement() pure const nothrow {
        static assert(BigDigit.sizeof is int.sizeof);
        return TwoComplementRange(this);
    }

    @trusted void check_minuz_zero() const pure {
        version (none)

            

                .check(sign && (_data.length is 1) && (_data[0] is 0),
        "The number minus zero is not allowed");
    }

    struct TwoComplementRange {
    @nogc:
        protected {
            bool overflow;
            const(BigDigit)[] data;
            long current;
            bool _empty;
        }
        immutable bool sign;

        @disable this();
        @trusted this(const BigNumber num) pure nothrow {
            sign = num._sign;
            overflow = true;
            data = num._data;
            popFront;
        }

        @property pure nothrow {
            const {
                long front() {
                    return current;
                }

                bool empty() {
                    return _empty;
                }
            }
            void popFront() {
                if (data.length) {
                    //debug writefln("data[0]=%d sign=%s", data[0], sign);
                    if (sign) {
                        current = data[0];
                        current = ~current;
                        if (overflow) {
                            overflow = (current == -1);
                            current++;
                        }
                        //debug writefln("data[0]=%08X current=%016X", data[0], current);
                    }
                    else {
                        current = data[0];
                    }
                    //debug writefln("\tcurrent=%d front=%d", current, front);
                    data = data[1 .. $];
                }
                else {
                    _empty = true;
                }
            }
        }
    }

    unittest { // Test of Two complement
        import std.algorithm.comparison : equal;

        {
            const x = BigNumber(0);
            assert(equal(x.two_complement, [0]));
        }

        {
            const x = BigNumber(uint.max);
            assert(equal(x.two_complement, [uint.max]));
        }

        {
            const x = BigNumber(-1);
            assert(equal(x.two_complement, [ulong.max]));
        }

        {
            const x = BigNumber(-2);
            assert(equal(x.two_complement, [ulong.max - 1]));
        }

        {
            const x = BigNumber(-0x2_0000_0000);
            assert(equal(x.two_complement, [0, 0xFFFFFFFFFFFFFFFE]));
        }

        {
            const x = BigNumber(long.min);
            assert(equal(x.two_complement, [0, 0xFFFFFFFF80000000]));
        }

        {
            BigNumber x;
            x = long.min;
            x *= 2;
            x -= 2;
            assert(equal(x.two_complement, [
                0xfffffffffffffffe, 0xffffffffffffffff, 0xfffffffffffffffe
            ]));
        }

        {
            const x = BigNumber("0xAB341234_6789ABCD_EF01AB34_12346789_ABCDEF01");
            assert(equal(x.two_complement, [
                0xABCDEF01, 0x12346789, 0xEF01AB34, 0x6789ABCD, 0xAB341234
            ]));
        }

        {
            const x = BigNumber("-0xAB341234_6789ABCD_EF01AB34_12346789_ABCDEF01");
            const(ulong[]) x_twoc = [
                ~0xABCDEF01UL + 1, ~0x12346789UL, ~0xEF01AB34UL, ~0x6789ABCDUL,
                ~0xAB341234UL
            ];
            assert(equal(x.two_complement, x_twoc));
        }

        {
            const x = BigNumber("-0xAB341234_6789ABCD_EF01AB34_12346789_00000000");
            const(ulong[]) x_twoc = [
                ~0x0000_0000UL + 1, ~0x12346789UL + 1, ~0xEF01AB34UL,
                ~0x6789ABCDUL, ~0xAB341234UL
            ];
            assert(equal(x.two_complement, x_twoc));
        }

        {
            const x = BigNumber("-0xAB341234_6789ABCD_EF01AB34_00000000_00000000");
            const(ulong[]) x_twoc = [
                ~0x0000_0000UL + 1, ~0x00000000UL + 1, ~0xEF01AB34UL + 1,
                ~0x6789ABCDUL, ~0xAB341234UL
            ];
            assert(equal(x.two_complement, x_twoc));
        }

        {
            const x = BigNumber("-0xAB341234_6789ABCD_00000000_00000000_00000000");
            const(ulong[]) x_twoc = [
                ~0x0000_0000UL + 1, ~0x00000000UL + 1, ~0x00000000UL + 1,
                ~0x6789ABCDUL + 1, ~0xAB341234UL
            ];
            assert(equal(x.two_complement, x_twoc));
        }

        {
            const x = BigNumber("-0xAB341234_00000000_00000000_00000000_00000000");
            const(ulong[]) x_twoc = [
                ~0x0000_0000UL + 1, ~0x00000000UL + 1, ~0x00000000UL + 1,
                ~0x00000000UL + 1, ~0xAB341234UL + 1
            ];
            assert(equal(x.two_complement, x_twoc));
        }
    }

    @nogc static size_t calc_size(const(ubyte[]) data) pure nothrow {
        size_t result;
        foreach (d; data) {
            result++;
            if ((d & 0x80) is 0) {
                return result;
            }
        }
        return 0;
    }

    alias serialize = encodeLEB128;
    immutable(ubyte[]) encodeLEB128() const pure {
        check_minuz_zero;
        immutable DATA_SIZE = (BigDigit.sizeof * data.length * 8) / 7 + 2;
        enum DIGITS_BIT_SIZE = BigDigit.sizeof * 8;
        scope buffer = new ubyte[DATA_SIZE];
        auto range2c = two_complement;

        long value = range2c.front;
        range2c.popFront;
        uint shift = DIGITS_BIT_SIZE;
        foreach (i, ref d; buffer) {
            if ((shift < 7) && (!range2c.empty)) {
                //debug writefln("range2c.front=%08x 0x%08x %d", range2c.front, value, shift);
                value &= ~(~0L << shift);
                value |= (range2c.front << shift);
                shift += DIGITS_BIT_SIZE;
                range2c.popFront;
            }
            d = value & 0x7F;
            shift -= 7;
            value >>= 7;
            if (range2c.empty && (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40)))) {
                return buffer[0 .. i + 1].idup;
            }
            d |= 0x80;
        }
        assert(0);
    }

    @nogc size_t calc_size() const pure nothrow {
        immutable DATA_SIZE = (BigDigit.sizeof * data.length * 8) / 7 + 1;
        enum DIGITS_BIT_SIZE = BigDigit.sizeof * 8;
        size_t index;
        auto range2c = two_complement;

        long value = range2c.front;
        range2c.popFront;

        uint shift = DIGITS_BIT_SIZE;
        //debug writefln("DATA_SIZE=%d", DATA_SIZE);
        foreach (i; 0 .. DATA_SIZE) {
            if ((shift < 7) && (!range2c.empty)) {
                value &= ~(~0L << shift);
                value |= (range2c.front << shift);
                shift += DIGITS_BIT_SIZE;
                version (none)
                    if (range2c.front & int.min) {
                        // Set sign bit
                        value |= (~0L) << shift;
                    }
                range2c.popFront;
            }
            scope d = value & 0x7F;
            //debug writefln("SIZE %d %02x %016x %s shift=%d", i, d, value, range2c.empty, shift);
            shift -= 7;
            value >>= 7;

            if (range2c.empty && (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40)))) {
                return i + 1;
            }
            d |= 0x80;
        }
        assert(0);
    }

    alias DecodeLEB128 = Tuple!(BigNumber, "value", size_t, "size");

    static DecodeLEB128 decodeLEB128(const(ubyte[]) data) pure nothrow {
        scope values = new uint[data.length / BigDigit.sizeof + 1];
        enum DIGITS_BIT_SIZE = uint.sizeof * 8;
        ulong result;
        uint shift;
        bool sign;
        size_t index;
        size_t size;
        foreach (i, d; data) {
            size++;
            result |= ulong(d & 0x7F) << shift;
            shift += 7;
            if (shift >= DIGITS_BIT_SIZE) {
                values[index++] = result & uint.max;
                result >>= DIGITS_BIT_SIZE;
                shift -= DIGITS_BIT_SIZE;
            }
            if ((d & 0x80) == 0) {
                if ((d & 0x40) != 0) {
                    result |= (~0L << shift);
                    sign = true;
                }
                const v = cast(int)(result & uint.max);
                values[index++] = v;
                //size=i;
                break;
            }
        }
        auto result_data = values[0 .. index];
        if (sign) {
            // Takes the to complement of the result because BigInt
            // is stored as a unsigned value and a sign
            long current;
            bool overflow = true;
            foreach (i, ref r; result_data) {
                current = r;
                current = ~current;
                if (overflow) {
                    overflow = (current == -1);
                    current++;
                }
                r = current & uint.max;
            }
        }
        while ((index > 1) && (result_data[index - 1] is 0)) {
            index--;
        }
        return DecodeLEB128(BigNumber(result_data[0 .. index], sign), size);
    }

}

unittest {
    import std.algorithm.comparison : equal;
    import std.stdio;
    import LEB128 = tagion.utils.LEB128;

    void ok(BigNumber x, const(ubyte[]) expected) {
        const encoded = x.encodeLEB128;
        assert(encoded == expected);
        assert(equal(encoded, expected));
        assert(x.calc_size == expected.length);
        const size = BigNumber.calc_size(expected);
        assert(size == expected.length);
        const decoded = BigNumber.decodeLEB128(expected);
        assert(decoded.value._data == x._data);
        assert(decoded.value.sign == x.sign);
        assert(decoded.size == size);
        assert(decoded.value == x);
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

    { // Small negative numbers
        ok(BigNumber(-1), [127]);
        ok(BigNumber(-100), LEB128.encode!long(-100));
        ok(BigNumber(-1000), LEB128.encode!long(-1000));
        ok(BigNumber(int.min), LEB128.encode!long(int.min));
        ok(BigNumber(long(int.min) * 2), LEB128.encode!long(long(int.min) * 2));
        ok(BigNumber(long.min), LEB128.encode!long(long.min));
    }

    { // Big positive number
        BigNumber x;
        {
            x = ulong.max;
            x = x * 2;
            ok(x, [254, 255, 255, 255, 255, 255, 255, 255, 255, 3]);
            x++;
            ok(x, [255, 255, 255, 255, 255, 255, 255, 255, 255, 3]);
        }

        {
            x = BigNumber("0xAB341234_6789ABCD_EF01AB34_12346789_ABCDEF01");
            ok(x, [
                129, 222, 183, 222, 154, 241, 153, 154, 146, 232, 172, 141,
                240, 189, 243, 213, 137, 207, 209, 145, 193, 230, 42
            ]);
        }

    }

    { // Big Negative number
        BigNumber x;
        {
            x = long.min;
            x *= 2;
            ok(x, [128, 128, 128, 128, 128, 128, 128, 128, 128, 126]);
            x--;
            ok(x, [255, 255, 255, 255, 255, 255, 255, 255, 255, 125]);
            x--;
            ok(x, [254, 255, 255, 255, 255, 255, 255, 255, 255, 125]);
        }

        {
            x = BigNumber("-0x1_0000_0000_0000_0000_0000_0000");
            ok(x, [
                128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
                128, 96
            ]);
            x--;
            ok(x, [
                255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 95
            ]);
            x--;
            ok(x, [
                254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 95
            ]);
        }

        {
            x = BigNumber("-0xAB341234_6789ABCD_EF01AB34_12346789_ABCDEF01");
            ok(x, [
                255, 161, 200, 161, 229, 142, 230, 229, 237, 151, 211, 242,
                143, 194, 140, 170, 246, 176, 174, 238, 190, 153, 85
            ]);

            x = BigNumber("-0xAB341234_6789ABCD_EF01AB34_12346789_00000000");
            ok(x, [
                128, 128, 128, 128, 240, 142, 230, 229, 237, 151, 211, 242,
                143, 194, 140, 170, 246, 176, 174, 238, 190, 153, 85
            ]);

            x = BigNumber("-0xAB341234_6789ABCD_EF01AB34_00000000_00000000");
            ok(x, [
                128, 128, 128, 128, 128, 128, 128, 128, 128, 152, 211, 242,
                143, 194, 140, 170, 246, 176, 174, 238, 190, 153, 85
            ]);

            x = BigNumber("-0xAB341234_6789ABCD_00000000_00000000_00000000");
            ok(x, [
                128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
                128, 224, 140, 170, 246, 176, 174, 238, 190, 153, 85
            ]);

            x = BigNumber("-0xAB341234_00000000_00000000_00000000_00000000");
            ok(x, [
                128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
                128, 128, 128, 128, 128, 128, 176, 238, 190, 153, 85
            ]);
        }
    }
}
