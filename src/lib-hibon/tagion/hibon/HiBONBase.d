module tagion.hibon.HiBONBase;

import tagion.basic.Basic : isOneOf;

import tagion.utils.StdTime;

import std.format;
import std.meta : AliasSeq, allSatisfy;
import std.traits : isBasicType, isSomeString, isNumeric, isType, EnumMembers,
    Unqual, getUDAs, hasUDA;
import std.typecons : tuple, TypedefType;
import std.range.primitives : isInputRange;

import std.system : Endian;
import bin = std.bitmanip;
import tagion.hibon.HiBONException;
import tagion.hibon.BigNumber;
import LEB128 = tagion.utils.LEB128;

alias binread(T, R) = bin.read!(T, Endian.littleEndian, R);
enum HIBON_VERSION = 0;

/++
 Helper function to serialize a HiBON
+/
void binwrite(T, R, I)(R range, const T value, I index) pure {
    import std.typecons : TypedefType;

    alias BaseT = TypedefType!(T);
    bin.write!(BaseT, Endian.littleEndian, R)(range, cast(BaseT) value, index);
}

/++
 Helper function to serialize an array of the type T of a HiBON
+/
@safe void array_write(T)(ref ubyte[] buffer, T array, ref size_t index) pure
if (is(T : U[], U) && isBasicType!U) {
    const ubytes = cast(const(ubyte[])) array;
    immutable new_index = index + ubytes.length;
    scope (success) {
        index = new_index;
    }
    buffer[index .. new_index] = ubytes;
}

/++
 HiBON Type codes
+/
enum Type : ubyte {
    NONE = 0x00, /// End Of Document
    STRING = 0x02, /// UTF8 STRING
    DOCUMENT = 0x03, /// Embedded document (Both Object and Documents)
    BINARY = 0x05, /// Binary data

    BOOLEAN = 0x08, /// Boolean - true or false
    TIME = 0x09, /// Standard Time counted as the total 100nsecs from midnight, January 1st, 1 A.D. UTC.
    HASHDOC = 0x0F, /// Hash point to documement, public key or signature

    INT32 = 0x11, /// 32-bit integer
    INT64 = 0x12, /// 64-bit integer,
    // INT128 = 0x13, /// 128-bit integer,

    UINT32 = 0x21, /// 32 bit unsigend integer
    UINT64 = 0x22, /// 64 bit unsigned integer
    // UINT128 = 0x23, /// 128-bit unsigned integer,

    FLOAT32 = 0x31, /// 32 bit Float
    FLOAT64 = 0x32, /// Floating point
    //       FLOAT128        = 0x33, /// 128bits Floating point
    BIGINT = 0x3B, /// Signed Bigint

    VER = 0x3F, /// Version field
    DEFINED_NATIVE = 0x40, /// Reserved as a definition tag it's for Native types
    NATIVE_DOCUMENT = DEFINED_NATIVE | 0x3e, /// This type is only used as an internal represention (Document type)

    DEFINED_ARRAY = 0x80, /// Indicated an Intrinsic array types
    /// Native types is only used inside the BSON object
    NATIVE_HIBON_ARRAY = DEFINED_ARRAY | DEFINED_NATIVE | DOCUMENT,
    /// Represetents (HISON[]) is convert to an ARRAY of DOCUMENT's
    NATIVE_DOCUMENT_ARRAY = DEFINED_ARRAY | DEFINED_NATIVE | NATIVE_DOCUMENT,
    /// Represetents (Document[]) is convert to an ARRAY of DOCUMENT's
    NATIVE_STRING_ARRAY = DEFINED_ARRAY | DEFINED_NATIVE | STRING, /// Represetents (string[]) is convert to an ARRAY of string's
}

@safe struct DataBlock {
    protected {
        uint _type;
        immutable(ubyte)[] _data;
    }
    @nogc pure nothrow {
        @property uint type() const {
            return _type;
        }

        @property immutable(ubyte[]) data() const {
            return _data;
        }

        this(const DataBlock x) {
            _type = x._type;
            _data = x._data;
        }

        this(const uint type, immutable(ubyte[]) data) {
            _type = type;
            _data = data;
        }

        this(immutable(ubyte[]) data) {
            const leb128 = LEB128.decode!uint(data);
            _type = leb128.value;
            this._data = data[leb128.size .. $];
        }

        @property size_t size() const {
            return LEB128.calc_size(_type) + _data.length;
        }
    }

    immutable(ubyte[]) serialize() pure const nothrow {
        return LEB128.encode(_type) ~ _data;
    }
}

//alias HashDoc = DataBlock; //!(Type.HASHDOC);

enum isDataBlock(T) = is(T : const(DataBlock));

/++
 Returns:
 true if the type is a internal native HiBON type
+/
@safe @nogc bool isNative(Type type) pure nothrow {
    with (Type) {
        return ((type & DEFINED_NATIVE) !is 0) && (type !is DEFINED_NATIVE);
    }
}

/++
 Returns:
 true if the type is a internal native array HiBON type
+/
@safe @nogc bool isNativeArray(Type type) pure nothrow {
    with (Type) {
        return ((type & DEFINED_ARRAY) !is 0) && (isNative(type));
    }
}

/++
 Returns:
 true if the type is a valid HiBONType excluding narive types
+/
@safe bool isHiBONType(Type type) pure nothrow {
    bool[] make_flags() {
        bool[] str;
        str.length = ubyte.max + 1;
        with (Type) {
            static foreach (E; EnumMembers!Type) {
                str[E] = (!isNative(E) && (E !is NONE) && (E !is VER)
                        && (E !is DEFINED_ARRAY) && (E !is DEFINED_NATIVE));
            }
        }
        return str;
    }

    enum flags = make_flags;
    return flags[type];
}

/++
 Returns:
 true if the type is a valid HiBONType excluding narive types
+/
@safe bool isValidType(Type type) pure nothrow {
    bool[] make_flags() {
        bool[] str;
        str.length = ubyte.max + 1;
        with (Type) {
            static foreach (E; EnumMembers!Type) {
                str[E] = (E !is NONE);
            }
        }
        return str;
    }

    enum flags = make_flags;
    return flags[type];
}

@safe @nogc bool isDataBlock(Type type) pure nothrow {
    with (Type) {
        return (type is HASHDOC);
    }
}

@safe @nogc bool isLEB128Basic(Type type) pure nothrow {
    with (Type) {
        return (type is INT32) || (type is INT64) || (type is UINT32) || (type is INT64);
    }
}

///
@nogc static unittest {
    with (Type) {
        static assert(!isHiBONType(NONE));
        static assert(!isHiBONType(DEFINED_ARRAY));
        static assert(!isHiBONType(DEFINED_NATIVE));
        static assert(!isHiBONType(VER));
    }
}

enum isBasicValueType(T) = isBasicType!T || is(T : decimal_t);

/++
 HiBON Generic value used by the HiBON class and the Document struct
+/
@safe union ValueT(bool NATIVE = false, HiBON, Document) {
    @Type(Type.FLOAT32) float float32;
    @Type(Type.FLOAT64) double float64;
    // @Type(Type.FLOAT128)  decimal_t float128;
    @Type(Type.STRING) string text;
    @Type(Type.BOOLEAN) bool boolean;
    //  @Type(Type.LIST)
    static if (!is(HiBON == void)) {
        @Type(Type.DOCUMENT) HiBON document;
    }
    else static if (!is(Document == void)) {
        @Type(Type.DOCUMENT) Document document;
    }
    @Type(Type.TIME) sdt_t date;
    @Type(Type.INT32) int int32;
    @Type(Type.INT64) long int64;
    @Type(Type.UINT32) uint uint32;
    @Type(Type.UINT64) ulong uint64;
    @Type(Type.BIGINT) BigNumber bigint;
    @Type(Type.HASHDOC) DataBlock hashdoc;

    static if (!is(Document == void)) {
        @Type(Type.NATIVE_DOCUMENT) Document native_document;
    }
    @Type(Type.BINARY) immutable(ubyte)[] binary;
    static if (NATIVE) {
        @Type(Type.NATIVE_HIBON_ARRAY) HiBON[] native_hibon_array;
        @Type(Type.NATIVE_DOCUMENT_ARRAY) Document[] native_document_array;
        @Type(Type.NATIVE_STRING_ARRAY) string[] native_string_array;

    }
    // else {
    alias NativeValueDataTypes = AliasSeq!();
    // }
    protected template GetFunctions(string text, bool first, TList...) {
        static if (TList.length is 0) {
            enum GetFunctions = text
                ~ "else {\n    static assert(0, format(\"Not support illegal %s \", type )); \n}";
        }
        else {
            enum name = TList[0];
            enum member_code = "alias member=ValueT." ~ name ~ ";";
            mixin(member_code);
            static if (__traits(compiles, typeof(member)) && hasUDA!(member, Type)) {
                enum MemberType = getUDAs!(member, Type)[0];
                alias MemberT = typeof(member);
                static if ((MemberType is Type.NONE) || (!NATIVE
                        && isOneOf!(MemberT, NativeValueDataTypes))) {
                    enum code = "";
                }
                else {
                    enum code = format("%sstatic if ( type is Type.%s ) {\n    return %s;\n}\n",
                                (first) ? "" : "else ", MemberType, name);
                }
                enum GetFunctions = GetFunctions!(text ~ code, false, TList[1 .. $]);
            }
            else {
                enum GetFunctions = GetFunctions!(text, false, TList[1 .. $]);
            }
        }

    }

    /++
     Returns:
     the value as HiBON type E
     +/

    @trusted @nogc auto by(Type type)() pure const {
        enum code = GetFunctions!("", true, __traits(allMembers, ValueT));
        mixin(code);
        assert(0);
    }

    protected template GetType(T, TList...) {
        static if (TList.length is 0) {
            enum GetType = Type.NONE;
        }
        else {
            enum name = TList[0];
            enum member_code = format(q{alias member=ValueT.%s;}, name);
            mixin(member_code);
            static if (__traits(compiles, typeof(member)) && hasUDA!(member, Type)) {
                enum MemberType = getUDAs!(member, Type)[0];
                alias MemberT = typeof(member);
                static if ((MemberType is Type.TIME) && is(T == sdt_t)) {
                    enum GetType = MemberType;
                }
                else static if (is(T == MemberT)) {
                    enum GetType = MemberType;
                }
                else {
                    enum GetType = GetType!(T, TList[1 .. $]);
                }
            }
            else {
                enum GetType = GetType!(T, TList[1 .. $]);
            }
        }
    }

    /++
     convert the T to a HiBON-Type
     +/
    enum asType(T) = GetType!(Unqual!T, __traits(allMembers, ValueT));
    /++
     is true if the type T is support by the HiBON
     +/
    enum hasType(T) = asType!T !is Type.NONE;

    version (none) static unittest {
        static assert(hasType!int);
    }

    static if (!is(Document == void) && is(HiBON == void)) {
        @trusted @nogc this(Document doc) pure nothrow {
            document = doc;
        }
    }

    static if (!is(Document == void) && !is(HiBON == void)) {
        @trusted @nogc this(Document doc) pure nothrow {
            native_document = doc;
        }
    }

    /++
     Construct a Value of the type T
     +/
    @trusted this(T)(T x) pure
    if (isOneOf!(Unqual!T, typeof(this.tupleof)) && !is(T == struct)) {
        alias MutableT = Unqual!T;
        alias Types = typeof(this.tupleof);
        foreach (i, ref m; this.tupleof) {
            static if (is(Types[i] == MutableT)) {
                m = x;
                return;
            }
        }
        assert(0, format("%s is not supported", T.stringof));
    }

    @trusted @nogc this(const DataBlock x) pure nothrow {
        hashdoc = x;
    }

    /++
     Constructs a Value of the type BigNumber
     +/
    @trusted @nogc this(const BigNumber big) pure nothrow {
        bigint = big;
    }

    @trusted @nogc this(const sdt_t x) pure nothrow {
        date = sdt_t(x);
    }

    /++
     Assign the value to x
     Params:
     x = value to be assigned
     +/
    @trusted @nogc void opAssign(T)(T x) if (isOneOf!(T, typeof(this.tupleof))) {
        alias UnqualT = Unqual!T;
        static foreach (m; __traits(allMembers, ValueT)) {
            static if (is(typeof(__traits(getMember, this, m)) == T)) {
                static if ((is(T == struct) || is(T == class))
                        && !__traits(compiles, __traits(getMember, this, m) = x)) {
                    enum code = format(q{alias member=ValueT.%s;}, m);
                    mixin(code);
                    enum MemberType = getUDAs!(member, Type)[0];
                    static assert(MemberType !is Type.NONE, format("%s is not supported", T));
                    x.copy(__traits(getMember, this, m));
                }
                else {
                    __traits(getMember, this, m) = cast(UnqualT) x;
                }
            }
        }
    }

    /++
     Assign of none standard HiBON types.
     This function will cast to type has the best match to the parameter x
     Params:
     x = sign value
     +/
    @nogc void opAssign(T)(T x) if (is(T == const) && isBasicType!T) {
        alias UnqualT = Unqual!T;
        opAssign(cast(UnqualT) x);
    }

    @nogc void opAssign(const sdt_t x) {
        date = cast(sdt_t) x;
    }

    /++
     Convert a HiBON Type to a D-type
     +/
    alias TypeT(Type aType) = typeof(by!aType());

    /++
     Returns:
     the size on bytes of the value as a HiBON type E
     +/
    @nogc uint size(Type E)() const pure nothrow {
        static if (isHiBONType(E)) {
            alias T = TypeT!E;
            static if (isBasicValueType!T || (E is Type.UTC)) {
                return T.sizeof;
            }
            else static if (is(T : U[], U) && isBasicValueType!U) {
                return cast(uint)(by!(E).length * U.sizeof);
            }
            else {
                static assert(0, format("Type %s of %s is not defined", E, T.stringof));
            }
        }
        else {
            static assert(0, format("Illegal type %s", E));
        }
    }

}

unittest {
    alias Value = ValueT!(false, void, void);
    Value test;
    with (Type) {
        test = Value(int(-42));
        assert(test.by!INT32 == -42);
        test = Value(long(-42));
        assert(test.by!INT64 == -42);
        test = Value(uint(42));
        assert(test.by!UINT32 == 42);
        test = Value(ulong(42));
        assert(test.by!UINT64 == 42);
        test = Value(float(42.42));
        assert(test.by!FLOAT32 == float(42.42));
        test = Value(double(17.42));
        assert(test.by!FLOAT64 == double(17.42));
        sdt_t time = 1001;
        test = Value(time);
        assert(test.by!TIME == time);
        test = Value("Hello");
        assert(test.by!STRING == "Hello");
    }
}

unittest {
    import std.typecons;

    alias Value = ValueT!(false, void, void);

    { // Check invalid type
        Value value;
        static assert(!__traits(compiles, value = 'x'));
    }

    { // Simple data type
        auto test_tabel = tuple(float(-1.23), double(2.34), "Text", true,
                ulong(0x1234_5678_9ABC_DEF0), int(-42), uint(42), long(-0x1234_5678_9ABC_DEF0));
        foreach (i, t; test_tabel) {
            Value v;
            v = test_tabel[i];
            alias U = test_tabel.Types[i];
            enum E = Value.asType!U;
            assert(test_tabel[i] == v.by!E);
        }
    }

    { // utc test,
        static assert(Value.asType!sdt_t is Type.TIME);
        sdt_t time = 1234;
        Value v;
        v = time;
        assert(v.by!(Type.TIME) == 1234);
        alias U = Value.TypeT!(Type.TIME);
        static assert(is(U == const sdt_t));
        static assert(!is(U == const ulong));
    }

}

/++
 Converts from a text to a index
 Params:
 a = the string to be converted to an index
 result = index value
 Returns:
 true if a is an index
+/
@safe @nogc bool is_index(const(char[]) a, out uint result) pure nothrow {
    import std.conv : to;

    enum MAX_UINT_SIZE = to!string(uint.max).length;
    @nogc @safe static ulong to_ulong(const(char[]) a) pure nothrow {
        ulong result;
        foreach (c; a) {
            result *= 10;
            result += (c - '0');
        }
        return result;
    }

    if (a.length <= MAX_UINT_SIZE) {
        if ((a[0] is '0') && (a.length > 1)) {
            return false;
        }
        foreach (c; a) {
            if ((c < '0') || (c > '9')) {
                return false;
            }
        }
        immutable number = to_ulong(a);
        if (number <= uint.max) {
            result = cast(uint) number;
            return true;
        }
    }
    return false;
}

/++
 Check if all the keys in range is indices and are consecutive
 Returns:
 true if keys is the indices of an HiBON array
+/
@safe bool isArray(R)(R keys) {
    bool check_array_index(const uint previous_index) {
        if (!keys.empty) {
            uint current_index;
            if (is_index(keys.front, current_index)) {
                if (previous_index + 1 == current_index) {
                    keys.popFront;
                    return check_array_index(current_index);
                }
            }
            return false;
        }
        return true;
    }

    if (!keys.empty) {
        uint previous_index;
        if (is_index(keys.front, previous_index)) {
            if (previous_index !is 0) {
                return false;
            }
            keys.popFront;
            return check_array_index(previous_index);
        }
        return false;
    }
    return true;
}

unittest {
    import std.algorithm : map;
    import std.conv : to;

    const(uint[]) null_index;
    assert(isArray(null_index.map!(a => a.to!string)));
    assert(!isArray([1].map!(a => a.to!string)));
    assert(isArray([0, 1].map!(a => a.to!string)));
    assert(!isArray([0, 2].map!(a => a.to!string)));
    assert(isArray([0, 1, 2].map!(a => a.to!string)));
    assert(!isArray(["x", "2"].map!(a => a)));
    assert(!isArray(["1", "x"].map!(a => a)));
    assert(!isArray(["0", "1", "x"].map!(a => a)));
}

///
unittest { // check is_index
    import std.conv : to;

    uint index;
    assert(is_index("0", index));
    assert(index is 0);
    assert(!is_index("-1", index));
    assert(is_index(uint.max.to!string, index));
    assert(index is uint.max);

    assert(!is_index(((cast(ulong) uint.max) + 1).to!string, index));

    assert(is_index("42", index));
    assert(index is 42);

    assert(!is_index("0x0", index));
    assert(!is_index("00", index));
    assert(!is_index("01", index));

    assert(is_index("7", index));
    assert(index is 7);
    assert(is_index("69", index));
    assert(index is 69);
}

/++
 This function decides the order of the HiBON keys
 Returns:
 true if the value of key a is less than the value of key b
+/
@safe @nogc bool less_than(string a, string b) pure nothrow
in {
    assert(a.length > 0);
    assert(b.length > 0);
}
do {
    uint a_index;
    uint b_index;
    if (is_index(a, a_index) && is_index(b, b_index)) {
        return a_index < b_index;
    }
    return a < b;
}

/++
 Checks if the keys in the range is ordred
 Returns:
 ture if all keys in the range is ordered
+/
@safe bool is_key_ordered(R)(R range) if (isInputRange!R) {
    string prev_key;
    while (!range.empty) {
        if ((prev_key.length == 0) || (less_than(prev_key, range.front))) {
            prev_key = range.front;
            range.popFront;
        }
        else {
            return false;
        }
    }
    return true;
}

enum isKeyString(T) = is(T : const(char[]));

enum isKey(T) = (isIntegral!(T) || isKeyString!(T));

///
unittest { // Check less_than
    import std.conv : to;

    assert(less_than("a", "b"));
    assert(less_than(0.to!string, 1.to!string));
    assert(!less_than("00", "0"));
    assert(less_than("0", "abe"));

    assert(less_than("7", "69"));
    // assert(less_than(0, "1"));
    // assert(less_than(5, 7));
}

/++
 Returns:
 true if the key is a valid HiBON key
+/
@safe bool is_key_valid(const(char[]) a) pure nothrow {
    enum : char {
        SPACE = 0x20,
        DEL = 0x7F,
        DOUBLE_QUOTE = 34,
        QUOTE = 39,
        BACK_QUOTE = 0x60
    }
    if (a.length > 0) {
        foreach (c; a) {
            // Chars between SPACE and DEL is valid
            // except for " ' ` is not valid
            if ((c <= SPACE) || (c >= DEL) || (c == DOUBLE_QUOTE) || (c == QUOTE)
                    || (c == BACK_QUOTE)) {
                return false;
            }
        }
        return true;
    }
    return false;
}

///
unittest { // Check is_key_valid
    import std.conv : to;
    import std.range : iota;
    import std.algorithm.iteration : map, each;

    assert(!is_key_valid(""));
    string text = " "; // SPACE
    assert(!is_key_valid(text));
    text = [0x80]; // Only simple ASCII
    assert(!is_key_valid(text));
    text = [char(34)]; // Double quote
    assert(!is_key_valid(text));
    text = "'"; // Sigle quote
    assert(!is_key_valid(text));
    text = "`"; // Back quote
    assert(!is_key_valid(text));
    text = "\0";
    assert(!is_key_valid(text));

    assert(is_key_valid("abc"));
    assert(is_key_valid(42.to!string));

    text = "";
    iota(0, ubyte.max).each!((i) => text ~= 'a');
    assert(is_key_valid(text));
    text ~= 'B';
    assert(is_key_valid(text));
}
