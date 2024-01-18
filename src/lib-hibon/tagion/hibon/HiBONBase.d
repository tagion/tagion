module tagion.hibon.HiBONBase;
import std.array;
import std.format;
import std.string : representation;
import std.meta : AliasSeq, allSatisfy;
import tagion.basic.basic : isOneOf;
import tagion.utils.StdTime;
import std.traits;
import bin = std.bitmanip;
import std.range.primitives : isInputRange;
import std.system : Endian;
import std.typecons : TypedefType, tuple;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBONException;
import LEB128 = tagion.utils.LEB128;

alias binread(T, R) = bin.read!(T, Endian.littleEndian, R);
enum HIBON_VERSION = 0;

alias AppendBuffer = Appender!(ubyte[]);
/++
 Helper function to serialize a HiBON
+/
void _binwrite(T)(ref scope AppendBuffer buffer, const T value) pure nothrow {
    import std.typecons : TypedefType;

    alias BaseT = TypedefType!(T);
    static if (T.sizeof == ubyte.sizeof) {
        buffer ~= value;
    }
    else {
        import std.bitmanip : append;

        append!(BaseT, Endian.littleEndian)(buffer, cast(BaseT) value);
    }
    //    __write("_binwrite %s value=%s %s %s", buffer.data, value, is(T==enum), BaseT.stringof);
}
/++
 Helper function to serialize an array of the type T of a HiBON
+/

void _buildKey(Key)(ref scope AppendBuffer buffer, Type type, Key key) pure
if (is(Key : const(char[])) || is(Key == uint)) {
    static if (is(Key : const(char[]))) {
        uint key_index;
        if (is_index(key, key_index)) {
            _buildKey(buffer, type, key_index);
            return;
        }
    }
    buffer._binwrite(type);

    static if (is(Key : const(char[]))) {
        buffer ~= LEB128.encode(key.length);
        buffer ~= key.representation;
    }
    else {
        buffer._binwrite(ubyte.init);
        const key_leb128 = LEB128.encode(key);
        buffer ~= key_leb128;
    }
}

void _build(T, Key)(ref scope AppendBuffer buffer, Type type, Key key,
        const(T) x) pure
if (is(Key : const(char[])) || is(Key == uint)) {
    import tagion.hibon.Document : Document;

    _buildKey(buffer, type, key);
    alias BaseT = TypedefType!T;
    static if (is(T : U[], U) && (U.sizeof == ubyte.sizeof)) {
        const leb128_size = LEB128.encode(x.length);
        buffer ~= leb128_size;
        static if (isSomeString!T) {
            buffer ~= x.representation;
        }
        else {
            buffer ~= x;
        }
    }
    else static if (is(T : const Document)) {
        buffer ~= x.data;
    }
    else static if (is(T : const BigNumber)) {
        buffer ~= x.serialize;
    }
    else static if (isIntegral!BaseT) {
        buffer ~= LEB128.encode(cast(BaseT) x);
    }
    else {
        buffer._binwrite(x);
    }
}

/++
 HiBON Type codes
+/
enum Type : ubyte {
    NONE = 0x00, /// End Of Document
    STRING = 0x01, /// UTF8 STRING
    DOCUMENT = 0x02, /// Embedded document (Both Object and Documents)
    BINARY = 0x03, /// Binary data

    BOOLEAN = 0x08, /// Boolean - true or false
    TIME = 0x09, /// Standard Time counted as the total 100nsecs from midnight, January 1st, 1 A.D. UTC.
    // HASHDOC = 0x0F, /// Hash point to documement, public key or signature

    INT32 = 0x11, /// 32-bit integer
    INT64 = 0x12, /// 64-bit integer,
    // INT128 = 0x13, /// 128-bit integer,

    UINT32 = 0x14, /// 32 bit unsigend integer
    UINT64 = 0x15, /// 64 bit unsigned integer
    // UINT128 = 0x16, /// 128-bit unsigned integer,

    FLOAT32 = 0x17, /// 32 bit Float
    FLOAT64 = 0x18, /// Floating point
    //       FLOAT128        = 0x19, /// 128bits Floating point
    BIGINT = 0x1A, /// Signed Bigint

    VER = 0x1F, /// Version field
    /// The following is only used internal (by HiBON) and should to be use in a stream Document
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

static unittest {
    enum SPACE = char(0x20);
    static assert(Type.VER < SPACE);
}

//alias HashDoc = DataBlock; //!(Type.HASHDOC);

//enum isDataBlock(T) = is(T : const(DataBlock));

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
 true if the type is a valid HiBONRecord excluding narive types
+/
@safe bool isHiBONBaseType(Type type) pure nothrow {
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
 true if the type is a valid HiBONRecord excluding narive types
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

@safe @nogc bool isLEB128Basic(Type type) pure nothrow {
    with (Type) {
        return (type is INT32) || (type is INT64) || (type is UINT32) || (type is INT64);
    }
}

///
@nogc static unittest {
    with (Type) {
        static assert(!isHiBONBaseType(NONE));
        static assert(!isHiBONBaseType(DEFINED_ARRAY));
        static assert(!isHiBONBaseType(DEFINED_NATIVE));
        static assert(!isHiBONBaseType(VER));
    }
}

enum isBasicValueType(T) = isBasicType!T || is(T : decimal_t);

/**
    Converts to the HiBON TypedefType except for sdt_t
*/
template TypedefBase(T) {
    static if (is(T : const(sdt_t))) {
        alias TypedefBase = T;
    }
    else {
        alias TypedefBase = TypedefType!T;
    }
}

@nogc
static unittest {
    import std.typecons;

    static assert(is(TypedefBase!int == int));
    alias MyInt = Typedef!(int, int.init, "MyInt");
    static assert(is(TypedefBase!(MyInt) == int));
    static assert(is(TypedefBase!(sdt_t) == sdt_t));
    static assert(is(TypedefBase!(const(sdt_t)) == const(sdt_t)));
}

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
    //@Type(Type.HASHDOC) DataBlock hashdoc;

    static if (!is(Document == void)) {
        @Type(Type.NATIVE_DOCUMENT) Document native_document;
    }
    @Type(Type.BINARY) immutable(ubyte)[] binary;
    static if (NATIVE) {
        @Type(Type.NATIVE_HIBON_ARRAY) HiBON[] native_hibon_array;
        @Type(Type.NATIVE_DOCUMENT_ARRAY) Document[] native_document_array;
        @Type(Type.NATIVE_STRING_ARRAY) string[] native_string_array;

    }
    alias NativeValueDataTypes = AliasSeq!();
    /++
     Returns:
     the value as HiBON type E
     +/

    @trusted @nogc auto by(Type type)() pure const {
        static foreach (i, name; FieldNameTuple!ValueT) {
            {
                enum member_code = format(q{alias member = ValueT.%s;}, name);
                mixin(member_code);
                enum MemberType = getUDAs!(member, Type)[0];
                alias MemberT = typeof(member);
                enum valid_value = !((MemberType is Type.NONE) || (!NATIVE
                            && isOneOf!(MemberT, NativeValueDataTypes)));

                static if (type is MemberType) {
                    static assert(valid_value, format("The type %s named ValueT.%s is not valid value", type, name));
                    return this.tupleof[i];
                }
            }
        }
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
    enum asType(T) = GetType!(Unqual!T, FieldNameTuple!ValueT);
    /++
     is true if the type T is support by the HiBON
     +/
    enum hasType(T) = asType!T !is Type.NONE;

    static unittest {
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
        static if (isHiBONBaseType(E)) {
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
    import std.algorithm.iteration : each, map;
    import std.conv : to;
    import std.range : iota;

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
