/// \file HiBONBase.d

module tagion.betterC.hibon.HiBONBase;

@nogc:

import std.meta : AliasSeq;
import std.range.primitives : isInputRange;
import std.traits : FieldNameTuple, Unqual, getUDAs, hasUDA, isBasicType, isIntegral, isNumeric, isSomeString, isType;

version (WebAssembly) {
    pragma(msg, "WebAssembler");
}
else {
    import core.stdc.stdio;
}

import tagion.betterC.hibon.BigNumber;
import tagion.betterC.hibon.Document;
import tagion.betterC.hibon.HiBON;
import tagion.betterC.utils.Bailout;
import tagion.betterC.utils.Basic;
import tagion.betterC.utils.BinBuffer;
import tagion.betterC.utils.Memory;
import tagion.betterC.utils.Text;
import tagion.betterC.utils.sdt;
import LEB128 = tagion.betterC.utils.LEB128;

enum HIBON_VERSION = 0;

/**
 * HiBON Type codes
 */
enum Type : ubyte {
    NONE = 0x00, /// End Of Document
    FLOAT64 = 0x01, /// Floating point
    STRING = 0x02, /// UTF8 STRING
    DOCUMENT = 0x03, /// Embedded document (Both Object and Documents)
    BINARY = 0x05, /// Binary data

    BOOLEAN = 0x08, /// Boolean - true or false
    TIME = 0x09, /// Standard Time counted as the total 100nsecs from midnight, January 1st, 1 A.D. UTC.
    INT32 = 0x10, /// 32-bit integer
    INT64 = 0x12, /// 64-bit integer,
    //       FLOAT128        = 0x13, /// Decimal 128bits
    BIGINT = 0x1B, /// Signed Bigint

    UINT32 = 0x20, /// 32 bit unsigned integer
    FLOAT32 = 0x21, /// 32 bit Float
    UINT64 = 0x22, /// 64 bit unsigned integer
    HASHDOC = 0x23, /// Hash point to documement, public key or signature
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

struct DataBlock {
@nogc:
    protected {
        uint _type;
        immutable(ubyte)[] _data;
    }
    @property uint type() const pure nothrow {
        return _type;
    }

    @property immutable(ubyte[]) data() const pure nothrow {
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

    void serialize(ref BinBuffer buffer) const {
        size_t index;
        LEB128.encode(buffer, _type);
        buffer.write(_data);
    }

    @property size_t size() pure const {
        return LEB128.calc_size(_type) + _data.length;
    }
}

//alias HashDoc = DataBlock; //!(Type.HASHDOC);

enum isDataBlock(T) = is(T : const(DataBlock));

version (none) struct Key {
@nogc:
    enum KeyType {
        NONE,
        DATA,
        TEXT,
        INDEX
    }

    protected {
        union {
            const(ubyte[]) data;
            Text text;
            uint index;
        }

        KeyType key_type;
    }

    this(const(char[]) key) {
        text = Text(key);
        key_type = KeyType.TEXT;
    }

    this(const uint index) {
        this.index = index;
        key_type = KeyType.INDEX;
    }

    this(const(ubyte[]) data) {
        this.data = data;
        key_type = KeyType.DATA;
    }

    ~this() {
        dispose;
    }

    size_t size() const pure {
        with (KeyType) {
            final switch (key_type) {
            case NONE:
                break;
            case DATA:
                if (data[0] is 0) {
                    return ubyte.sizeof + LEB128.calc_size(data[1 .. $]);
                }
                break;
            case TEXT:
                const leb128_len = LEB128.encode!uint(data);
                return leb128_len.size + leb128_len.value;
                break;
            case INDEX:
                return ubyte.sizeof + LEB128.calc_size(index);
            }
        }
        assert(0);
    }

    void dispose() {
        if (key_type is KeyType.DATA) {
            text.dispose;
        }
    }

    void serialize(ref BinBuffer bin) const {
        with (KeyType) {
            final switch (key_type) {
            case NONE:
                break;
            case DATA:
                bin.write(data);
                break;
            case TEXT:
                bin.write(text.serialize);
                break;
            case INDEX:
                LEB128.encode(bin, index);
            }
        }
        assert(0);
    }

    bool isIndex() const pure {
        with (KeyType) {
            final switch (key_type) {
            case DATA:
                return (data[0] is 0);
            case TEXT:
                size_t dummy;
                return is_index(text.serialize, dummy);
            case INDEX:
                return true;
            case NONE:
                return false;
            }
        }
        assert(0);
    }

    T to(T)() const if (is(T : const(char)[]) || is(T == uint)) {
        with (KeyType) {
            final switch (key_type) {
            case DATA:
                if (data[0] is 0) {
                    static if (is(T == uint)) {
                        return LEB128.decode!uint(data[1 .. $]).value;
                    }
                }
                else {
                    static if (is(T : const(char)[])) {
                        const leb128_len = LEB128.decode!uint(data);
                        return (cast(immutable(char)*) data.ptr)[leb128_len.size .. leb128_len.size + leb128_len
                            .value];
                    }
                }
                break;
            case TEXT:
                static if (is(T : const(char)[])) {
                    return text.serialize;
                }
                else {
                    uint key_index;
                    if (is_index(text.serialize, key_index)) {
                        return key_index;
                    }
                }
                break;
            case INDEX:
                static if (is(T == uint)) {
                    return index;
                }
            case NONE:

            }
            assert(0);
        }
    }

    int opCmp(const(char[]) b) const pure {
        return key_compare(data, b);
    }

    int opCmp(ref const Key b) const pure {
        return opCmp(b.data);
    }

    int opCmp(const(Key*) b) const pure {
        return opCmp(b.data);
    }

    bool opEquals(T)(T b) const pure {
        return opCmp(b) == 0;
    }

}

/**
 * @return true if the type is a internal native HiBON type
 */
bool isNative(Type type) pure nothrow {
    with (Type) {
        return ((type & DEFINED_NATIVE) !is 0) && (type !is DEFINED_NATIVE);
    }
}

/**
 Returns:
 true if the type is a internal native array HiBON type
 */
// bool isNativeArray(Type type) pure nothrow {
//     with(Type) {
//         return ((type & DEFINED_ARRAY) !is 0) && (isNative(type));
//     }
// }

/**
 * @return true if the type is a HiBON data array (This is not the same as HiBON.isArray)
 */
bool isArray(Type type) pure nothrow {
    with (Type) {
        return ((type & DEFINED_ARRAY) !is 0) && (type !is DEFINED_ARRAY) && (!isNative(type));
    }
}

mixin(Init_HiBON_Types!("__gshared immutable hibon_types=", 0));

/**
 * @return true if the type is a valid HiBONRecord excluding narive types
 */
bool isHiBONBaseType(Type type) {
    return hibon_types[type];
}

bool isDataBlock(Type type) pure nothrow {
    with (Type) {
        return (type is HASHDOC);
    }
}

template Init_HiBON_Types(string text, uint i) {
    static if (i is ubyte.max + 1) {
        enum Init_HiBON_Types = text ~ "];";
    }
    else {
        enum start_bracket = (i is 0) ? "[" : "";
        enum E = cast(Type) i;
        enum flag = (!isNative(E) && (E !is Type.NONE) && (E !is Type.VER) && (
                    E !is Type.DEFINED_ARRAY) && (E !is Type
                    .DEFINED_NATIVE));
        enum Init_HiBON_Types = Init_HiBON_Types!(text ~ start_bracket ~ flag.stringof ~ ",", i + 1);
    }
}

version (none) {

    enum isBasicValueType(T) = isBasicType!T || is(T : decimal_t);
}
/**
 * HiBON Generic value used by the HiBON class and the Document struct
 */
//@safe
union ValueT(bool NATIVE = false, HiBON, Document) {
@nogc:
    @Type(Type.FLOAT32) float float32;
    @Type(Type.FLOAT64) double float64;
    // @Type(Type.FLOAT128)  decimal_t float128;
    @Type(Type.STRING) string text;
    @Type(Type.BOOLEAN) bool boolean;
    //  @Type(Type.LIST)
    static if (!is(HiBON == void)) {
        @Type(Type.DOCUMENT) HiBON document;
        void dispose() {
            version (WebAssembly) {
            }
            else {
                printf("VALUE Dispose\n");
            }
        }
    }
    else static if (!is(Document == void)) {
        @Type(Type.DOCUMENT) Document document;
    }
    @Type(Type.TIME) sdt_t date;
    @Type(Type.INT32) int int32;
    @Type(Type.INT64) long int64;
    @Type(Type.UINT32) uint uint32;
    @Type(Type.UINT64) ulong uint64;
    // @Type(Type.BIGINT)     BigNumber bigint;
    // @Type(Type.HASHDOC)    DataBlock    hashdoc;
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
    alias NativeValueDataTypes = AliasSeq!();
    /**
     * @return the value as HiBON type E
      */
    @trusted @nogc auto by(Type type)() pure const {
        import std.format;

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
            enum member_code = "alias member=ValueT." ~ name ~ ";";
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

    /**
     * convert the T to a HiBON-Type
     */
    enum asType(T) = GetType!(Unqual!T, FieldNameTuple!(ValueT));

    /**
     is true if the type T is support by the HiBON
      */
    enum hasType(T) = asType!T !is Type.NONE;

    static if (!is(Document == void) && is(HiBON == void)) {
        this(Document doc) {
            document = doc;
        }
    }

    static if (!is(Document == void) && !is(HiBON == void)) {
        this(Document doc) {
            native_document = doc;
        }
    }

    /**
     * Construct a Value of the type T
     */
    this(T)(T x) if (isOneOf!(Unqual!T, typeof(this.tupleof)) && !is(T == struct)) {
        alias MutableT = Unqual!T;
        static foreach (m; __traits(allMembers, ValueT)) {
            static if (is(typeof(__traits(getMember, this, m)) == MutableT)) {
                enum code = "alias member=ValueT." ~ m ~ ";";
                mixin(code);
                static if (hasUDA!(member, Type)) {
                    alias MemberT = typeof(member);
                    static if (is(MutableT == MemberT)) {
                        __traits(getMember, this, m) = x;
                        return;
                    }
                }
            }
        }
        assert(0, T.stringof ~ " is not supported");
    }

    /**
     * Constructs a Value of the type BigNumber
     */
    this(const BigNumber big) pure {
        bigint = cast(BigNumber) big;
    }

    this(DataBlock datablock) pure {
        hashdoc = datablock;
    }

    @trusted this(const sdt_t x) pure {
        date = x;
    }

    /**
     * Assign the value to x
     * @param x = value to be assigned
     */
    void opAssign(T)(T x) if (isOneOf!(T, typeof(this.tupleof))) {
        alias UnqualT = Unqual!T;
        static foreach (m; __traits(allMembers, ValueT)) {
            static if (is(typeof(__traits(getMember, this, m)) == T)) {
                static if ((is(T == struct) || is(T == class)) && !__traits(compiles, __traits(getMember, this, m) = x)) {
                    enum code = "alias member=ValueT." ~ m ~ ";";
                    mixin(code);
                    enum MemberType = getUDAs!(member, Type)[0];
                    static assert(MemberType !is Type.NONE, T.stringof ~ " is not supported");
                    x.copy(__traits(getMember, this, m));
                }
                else {
                    __traits(getMember, this, m) = cast(UnqualT) x;
                }
            }
        }
    }

    // /**
    //  Assign of none standard HiBON types.
    //  This function will cast to type has the best match to he parameter x
    //  Params:
    //  x = sign value
    //   */
    // void opAssign(T)(T x) if (!isOneOf!(T, typeof(this.tupleof))) {
    //     alias UnqualT=Unqual!T;
    //     alias CastT=castTo!(UnqualT, CastTypes);
    //     static assert(is(CastT==void), "Type "~T.stringof~" not supported");
    //     alias E=asType!UnqualT;
    //     opAssign(cast(CastT)x);
    // }

    /**
     * Convert a HiBON Type to a D-type
     */
    alias TypeT(Type aType) = typeof(by!aType());

    /**
     * @return the size on bytes of the value as a HiBON type E
     */
    uint size(Type E)() const pure nothrow {
        static if (isHiBONBaseType(E)) {
            alias T = TypeT!E;
            static if (isBasicValueType!T || (E is Type.UTC)) {
                return T.sizeof;
            }
            else static if (is(T : U[], U) && isBasicValueType!U) {
                return cast(uint)(by!(E).length * U.sizeof);
            }
            else {
                static assert(0, "Type " ~ E.stringof ~ " of " ~ T.stringof ~ " is not defined");
            }
        }
        else {
            static assert(0, "Illegal type " ~ E.stringof);
        }
    }

}

// unittest {
//     alias Value = ValueT!(false, void, void);
//     Value test;
//     with(Type) {
//         test=Value(int(-42)); assert(test.by!INT32 == -42);
//         test=Value(long(-42)); assert(test.by!INT64 == -42);
//         test=Value(uint(42)); assert(test.by!UINT32 == 42);
//         test=Value(ulong(42)); assert(test.by!UINT64 == 42);
//         test=Value(float(42.42)); assert(test.by!FLOAT32 == float(42.42));
//         test=Value(double(17.42)); assert(test.by!FLOAT64 == double(17.42));
//         sdt_t time=1001;
//         test=Value(time); assert(test.by!TIME == time);
//         test=Value("Hello"); assert(test.by!STRING == "Hello");
//     }
// }

// unittest {
//     import std.typecons;
//     alias Value = ValueT!(false, void, void);

//     { // Check invalid type
//         Value value;
//         static assert(!__traits(compiles, value='x'));
//     }

//     { // Simple data type
//         auto test_table=tuple(
//             float(-1.23), double(2.34), "Text", true, ulong(0x1234_5678_9ABC_DEF0),
//             int(-42), uint(42), long(-0x1234_5678_9ABC_DEF0)
//             );
//         foreach(i, t; test_table) {
//             Value v;
//             v=test_table[i];
//             alias U = test_table.Types[i];
//             enum E  = Value.asType!U;
//             assert(test_table[i] == v.by!E);
//         }
//     }

//     version(none)
//     { // utc test,
//         static assert(Value.asType!sdt_t is Type.TIME);
//         sdt_t time = 1234;
//         Value v;
//         v = time;
//         assert(v.by!(Type.TIME) == 1234);
//         alias U = Value.TypeT!(Type.TIME);
//         static assert(is(U == const sdt_t));
//         static assert(!is(U == const ulong));
//     }

// }

/**
 * Converts from a text to a index
 * @param a = the string to be converted to an index
 * @param result = index value
 * @return true if a is an index
 */
// memcpy(return void* s1, scope const void* s2, size_t n);
bool is_index(const(char[]) a, out uint result) pure {
    enum MAX_UINT_SIZE = uint.max.stringof.length;
    if (a.length <= MAX_UINT_SIZE) {
        if ((a[0] is '0') && (a.length > 1)) {
            return false;
        }
        foreach (c; a) {
            if ((c < '0') || (c > '9')) {
                return false;
            }
        }
        immutable number = a.to_ulong;
        if (number <= uint.max) {
            result = cast(uint) number;
            return true;
        }
    }
    return false;
}

ulong to_ulong(const(char[]) num) pure {
    ulong result;
    foreach (a; num) {
        result *= 10;
        result += (a - '0');
    }
    return result;
}

uint to_uint(string num) pure {
    ulong result = to_ulong(num);
    //    .check(result <= uint.max, "Bad uint overflow");
    return cast(uint) result;
}

/**
 * Check if all the keys in range is indices and are consecutive
 * @return true if keys is the indices of an HiBON array
 */
version (none) bool isArray(R)(R keys) {
    bool check_array_index(const uint previous_index) {
        if (!keys.empty) {
            uint current_index;
            if (is_index(keys.front, current_index)) {
                if (previous_index + 1 is current_index) {
                    keys.popFront;
                    return check_array_index(current_index);
                }
            }
            return false;
        }
        return true;
    }

    if (!keys.empty) {
        uint previous_index = uint.max;
        if (is_index(keys.front, previous_index) && (previous_index is 0)) {
            keys.popFront;
            return check_array_index(previous_index);
        }
    }
    return false;
}

// ///
// unittest { // check is_index
//     uint index;
//     assert(is_index("0", index));
//     assert(index is 0);
//     assert(!is_index("-1", index));

//     assert(is_index(uint.max.stringof[0..$-1], index));
//     assert(index is uint.max);

//     enum overflow=((cast(ulong)uint.max)+1);
//     assert(!is_index(overflow.stringof, index));

//     assert(is_index("42", index));
//     assert(index is 42);

//     assert(!is_index("0x0", index));
//     assert(!is_index("00", index));
//     assert(!is_index("01", index));
// }

/**
 * This function decides the order of the HiBON keys
 */
int key_compare(const(char[]) a, const(char[]) b) pure
in {
    assert(a.length > 0);
    assert(b.length > 0);
}
do {
    int res = 1;
    uint a_index;
    uint b_index;
    if (is_index(a, a_index) && is_index(b, b_index)) {
        if (a_index < b_index) {
            res = -1;
        }
        else if (a_index == b_index) {
            res = 0;
        }
        res = 1;
    }
    if (a.length == b.length) {
        res = 0;
        foreach (i, elem; a) {
            if (elem != b[i]) {
                res = 1;
                break;
            }
        }
    }
    else if (a < b) {
        res = -1;
    }
    return res;
}

/**
 * Checks if the keys in the range is ordred
 * @return true if all keys in the range is ordered
 */
bool is_key_ordered(R)(R range) if (isInputRange!R) {
    string prev_key;
    while (!range.empty) {
        if ((prev_key.length == 0) || (key_compare(prev_key, range.front) < 0)) {
            prev_key = range.front;
            range.popFront;
        }
        else {
            return false;
        }
    }
    return true;
}

// ///
// unittest { // Check less_than
//     assert(key_compare("a", "b") < 0);
//     assert(key_compare("0", "1") < 0);
//     assert(key_compare("00", "0") > 0);
//     assert(key_compare("0", "abe") < 0);
//     assert(key_compare("42", "abe") < 0);
//     assert(key_compare("42", "17") > 0);
//     assert(key_compare("42", "42") == 0);
//     assert(key_compare("abc", "abc") == 0);
// }

/**
 * @return true if the key is a valid HiBON key
 */
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
            if ((c <= SPACE) || (c >= DEL) ||
                    (c == DOUBLE_QUOTE) || (c == QUOTE) ||
                    (c == BACK_QUOTE)) {
                return false;
            }
        }
        return true;
    }
    return false;
}

///
// unittest { // Check is_key_valid
//     assert(!is_key_valid(""));
//     string text=" "; // SPACE
//     assert(!is_key_valid(text));
//     text="\x80"; // Only simple ASCII
//     assert(!is_key_valid(text));
//     text=`"`; // Double quote
//     assert(!is_key_valid(text));
//     text="'"; // Sigle quote
//     assert(!is_key_valid(text));
//     text="`"; // Back quote
//     assert(!is_key_valid(text));
//     text="\0";
//     assert(!is_key_valid(text));

//     assert(is_key_valid("abc"));
//     assert(is_key_valid("42"));

//     text="";
//     char[ubyte.max+1] max_key_size;
//     foreach(ref a; max_key_size) {
//         a='a';
//     }
//     assert(is_key_valid(max_key_size[0..$-1]));
//     assert(is_key_valid(max_key_size));
// }

template isOneOf(T, TList...) {
    static if (TList.length == 0) {
        enum isOneOf = false;
    }
    else static if (is(T == TList[0])) {
        enum isOneOf = true;
    }
    else {
        alias isOneOf = isOneOf!(T, TList[1 .. $]);
    }
}
