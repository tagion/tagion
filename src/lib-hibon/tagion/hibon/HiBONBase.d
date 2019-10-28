module tagion.hibon.HiBONBase;

import tagion.Types;
import tagion.Base : isOneOf;
import tagion.TagionExceptions : Check, TagionException;

import std.format;
import std.meta : AliasSeq; //, Filter;
import std.traits : isBasicType, isSomeString, isIntegral, isNumeric, isType, EnumMembers, Unqual, getUDAs, hasUDA;
import std.typecons : Typedef;

import std.system : Endian;
import bin = std.bitmanip;

alias binread(T, R) = bin.read!(T, Endian.littleEndian, R);

void binwrite(T, R, I)(R range, const T value, I index) pure {
    import std.typecons : TypedefType;
    alias BaseT=TypedefType!(T);
    bin.write!(BaseT, Endian.littleEndian, R)(range, cast(BaseT)value, index);
}

/**
 * Exception type used by tagion.utils.BSON module
 */
@safe
class HiBONException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

alias check=Check!HiBONException;


enum Type : ubyte {
//     MIN             = -1,       /// Special type which compares lower than all other possible BSON element values
    NONE            = 0x00,  /// End Of Document
        FLOAT64         = 0x01,  /// Floating point
        STRING          = 0x02,  /// UTF8 STRING
        DOCUMENT        = 0x03,  /// Embedded document (Both Object and Documents)
        BOOLEAN         = 0x08,  /// Boolean - true or false
        UTC             = 0x09,  /// UTC datetime
        INT32           = 0x10,  /// 32-bit integer
        INT64           = 0x12,  /// 64-bit integer,
        //       FLOAT128        = 0x13, /// Decimal 128bits
        //       BIGINT          = 0x1B,  /// Signed Bigint

        UINT32          = 0x20,  // 32 bit unsigend integer
        FLOAT32         = 0x21,  // 32 bit Float
        UINT64          = 0x22,  // 64 bit unsigned integer
//        HASHDOC         = 0x23,  // Hash point to documement
//        UBIGINT         = 0x2B,  /// Unsigned Bigint
//        TRUNC           = 0x3f,  // Mask for basic values


        DEFINED_NATIVE  = 0x40,
        NATIVE_DOCUMENT = DEFINED_NATIVE | 0x3e, // This type is only used as an internal represention (Document type)

        DEFINED_ARRAY   = 0x80,  // Indicated an Intrinsic array types
        BINARY          = DEFINED_ARRAY | 0x05, // Binary data
        INT32_ARRAY     = DEFINED_ARRAY | INT32,
        INT64_ARRAY     = DEFINED_ARRAY | INT64,
        FLOAT64_ARRAY   = DEFINED_ARRAY | FLOAT64,
        BOOLEAN_ARRAY   = DEFINED_ARRAY | BOOLEAN,
        UINT32_ARRAY    = DEFINED_ARRAY | UINT32,
        UINT64_ARRAY    = DEFINED_ARRAY | UINT64,
        FLOAT32_ARRAY   = DEFINED_ARRAY | FLOAT32,
        //     FLOAT128_ARRAY   = DEFINED_ARRAY | FLOAT128,

        /// Native types is only used inside the BSON object
        NATIVE_HIBON_ARRAY    = DEFINED_ARRAY | DEFINED_NATIVE | DOCUMENT, // Represetents (HISON[]) is convert to an ARRAY of DOCUMENT's
        NATIVE_DOCUMENT_ARRAY = DEFINED_ARRAY | DEFINED_NATIVE | NATIVE_DOCUMENT, // Represetents (Document[]) is convert to an ARRAY of DOCUMENT's
        NATIVE_STRING_ARRAY   = DEFINED_ARRAY | DEFINED_NATIVE | STRING, // Represetents (string[]) is convert to an ARRAY of string's
        }

alias utc_t = Typedef!(ulong, ulong.init, Type.UTC.stringof);

@safe
bool isNative(Type type) pure nothrow {
    with(Type) {
        return ((type & DEFINED_NATIVE) !is 0) && (type !is DEFINED_NATIVE);
    }
}

@safe
bool isNativeArray(Type type) pure nothrow {
    with(Type) {
        return ((type & DEFINED_ARRAY) !is 0) && (isNative(type));
    }
}

@safe
bool isArray(Type type) pure nothrow {
    with(Type) {
        return ((type & DEFINED_ARRAY) !is 0) && (type !is DEFINED_ARRAY) && (!isNative(type));
    }
}

@safe
bool isHiBONType(Type type) pure nothrow {
    bool[] make_flags() {
        bool[] str;
        str.length = ubyte.max+1;
        with(Type) {
            static foreach(E; EnumMembers!Type) {
                str[E]=(!isNative(E) && (E !is NONE) && (E !is DEFINED_ARRAY) && (E !is DEFINED_NATIVE));
            }
        }
        return str;
    }
    enum flags = make_flags;
    return flags[type];
}

static unittest {
    with(Type) {
        static assert(!isHiBONType(NONE));
        static assert(!isHiBONType(DEFINED_ARRAY));
        static assert(!isHiBONType(DEFINED_NATIVE));
    }

}
/*
  static unittest {
  with(Type) {
  assert(isHiBON(
  }
*/

//@safe class HiBON;
//@safe struct Document;

enum isBasicValueType(T) = isBasicType!T || is(T : decimal_t);

@safe
union ValueT(bool NATIVE=false, HiBON,  Document) {
    @Type(Type.FLOAT32)   float     float32;
    @Type(Type.FLOAT64)   double    float64;
    // @Type(Type.FLOAT128)  decimal_t float128;
    @Type(Type.STRING)    string    text;
    @Type(Type.BOOLEAN)   bool      boolean;
    //  @Type(Type.LIST)
    static if ( !is(HiBON == void ) ) {
        @Type(Type.DOCUMENT)  HiBON      document;
    }
    else static if ( !is(Document == void ) ) {
        @Type(Type.DOCUMENT)  Document      document;
    }
    // static if ( !is(HiList == void ) ) {
    //     @Type(Type.LIST)  HiList    list;
    // }
    @Type(Type.UTC)       utc_t     date;
    @Type(Type.INT32)     int       int32;
    @Type(Type.INT64)     long      int64;
    @Type(Type.UINT32)    uint      uint32;
    @Type(Type.UINT64)    ulong     uint64;
    static if ( !is(Document == void) ) {
        @Type(Type.NATIVE_DOCUMENT) Document    native_document;
    }
    @Type(Type.BINARY)         immutable(ubyte)[]   binary;
    @Type(Type.BOOLEAN_ARRAY)  immutable(bool)[]    boolean_array;
    @Type(Type.INT32_ARRAY)    immutable(int)[]     int32_array;
    @Type(Type.UINT32_ARRAY)   immutable(uint)[]    uint32_array;
    @Type(Type.INT64_ARRAY)    immutable(long)[]    int64_array;
    @Type(Type.UINT64_ARRAY)   immutable(ulong)[]   uint64_array;
    @Type(Type.FLOAT32_ARRAY)  immutable(float)[]   float32_array;
    @Type(Type.FLOAT64_ARRAY)  immutable(double)[]  float64_array;
    // @Type(Type.FLOAT128_ARRAY) immutable(decimal_t)[] float128_array;
    static if ( NATIVE ) {
        @Type(Type.NATIVE_HIBON_ARRAY)    HiBON[]     native_hibon_array;
        @Type(Type.NATIVE_DOCUMENT_ARRAY) Document[]  native_document_array;
        @Type(Type.NATIVE_STRING_ARRAY) string[]    native_string_array;
        //  @Type(Type.NONE) alias NativeValueDataTypes = AliasSeq!(HiBON, HiBON[], Document[]);

    }
    // else {
    alias NativeValueDataTypes = AliasSeq!();
    // }
    protected template GetFunctions(string text, bool first, TList...) {
        static if ( TList.length is 0 ) {
            enum GetFunctions=text~"else {\n    static assert(0, format(\"Not support illegal %s \", type )); \n}";
        }
        else {
            enum name=TList[0];
            enum member_code="alias member=ValueT."~name~";";
            mixin(member_code);
            static if (  __traits(compiles, typeof(member)) && hasUDA!(member, Type) ) {
                enum MemberType=getUDAs!(member, Type)[0];
                alias MemberT=typeof(member);
                static if ( (MemberType is Type.NONE) || ( !NATIVE && isOneOf!(MemberT, NativeValueDataTypes)) ) {
                    enum code="";
                }
                else {
                    enum code = format("%sstatic if ( type is Type.%s ) {\n    return %s;\n}\n",
                        (first)?"":"else ", MemberType, name);
                }
                enum GetFunctions=GetFunctions!(text~code, false, TList[1..$]);
            }
            else {
                enum GetFunctions=GetFunctions!(text, false, TList[1..$]);
            }
        }

    }

    @trusted
    auto by(Type type)() pure const {
        enum code=GetFunctions!("", true, __traits(allMembers, ValueT));
//        pragma(msg, code);
        mixin(code);
        assert(0);
    }

    protected template GetType(T, TList...) {
        static if (TList.length is 0) {
            enum GetType = Type.NONE;
        }
        else {
            enum name = TList[0];
            enum member_code = "alias member=ValueT."~name~";";
            mixin(member_code);
            static if ( __traits(compiles, typeof(member)) && hasUDA!(member, Type) ) {
                enum MemberType=getUDAs!(member, Type)[0];
                alias MemberT=typeof(member);
                static if ( (MemberType is Type.UTC) && is(T == utc_t) ) {
                    enum GetType = MemberType;
                }
                else static if ( is(T == MemberT) ) {
                    enum GetType = MemberType;
                }
                else {
                    enum GetType = GetType!(T, TList[1..$]);
                }
            }
            else {
                enum GetType = GetType!(T, TList[1..$]);
            }
        }
    }

    enum asType(T) = GetType!(Unqual!T, __traits(allMembers, ValueT));
    enum hasType(T) = asType!T !is Type.NONE;

    version(none)
    static unittest {
        static assert(hasType!int);
    }

    static if (!is(Document == void) && is(HiBON == void)) {
        @trusted
            this(Document doc) {
            document = doc;
        }
    }

    static if (!is(Document == void) && !is(HiBON == void) ) {
        @trusted
        this(Document doc) {
            native_document = doc;
        }
    }

    @trusted
    this(T)(T x) if (isOneOf!(Unqual!T, typeof(this.tupleof)) && !is(T : const(Document)) ) {
        alias MutableT = Unqual!T;
        static foreach(m; __traits(allMembers, ValueT) ) {
            static if ( is(typeof(__traits(getMember, this, m)) == MutableT ) ){
                enum code=format("alias member=ValueT.%s;", m);
                mixin(code);
                static if ( hasUDA!(member, Type ) ) {
                    alias MemberT   = typeof(member);
                    static if ( is(T == MemberT) ) {
                        __traits(getMember, this, m) = x;
                        return;
                    }
                }
            }
        }
        assert (0, format("%s is not supported", T.stringof ) );
    }

    @trusted
    void opAssign(T)(T x) if (isOneOf!(T, typeof(this.tupleof))) {
        alias UnqualT = Unqual!T;
        static foreach(m; __traits(allMembers, ValueT) ) {
            static if ( is(typeof(__traits(getMember, this, m)) == T ) ){
                static if ( (is(T == struct) || is(T == class)) && !__traits(compiles, __traits(getMember, this, m) = x) ) {
                    enum code="alias member=ValueT."~m~";";
                    mixin(code);
                    enum MemberType=getUDAs!(member, Type)[0];
                    static assert ( MemberType !is Type.NONE, format("%s is not supported", T ) );
                    x.copy(__traits(getMember, this, m));
                }
                else {
                    __traits(getMember, this, m) = cast(UnqualT)x;
                }
            }
        }
    }

    alias TypeT(Type aType) = typeof(by!aType());

    uint size(Type E)() const pure nothrow {
        static if (isHiBONType(E)) {
            alias T = TypeT!E;
            static if ( isBasicValueType!T || (E is Type.UTC)  ) {
                return T.sizeof;
            }
            else static if ( is(T: U[], U) && isBasicValueType!U ) {
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

};


unittest {
    import std.typecons;
    alias Value = ValueT!(false, void, void);

    { // Check invalid type
        Value value;
        static assert(!__traits(compiles, value='x'));
    }

    { // Simple data type
        auto test_tabel=tuple(
            float(-1.23), double(2.34), "Text", true, ulong(0x1234_5678_9ABC_DEF0),
            int(-42), uint(42), long(-0x1234_5678_9ABC_DEF0)
            );
        foreach(i, t; test_tabel) {
            Value v;
            v=test_tabel[i];
            alias U = test_tabel.Types[i];
            enum E  = Value.asType!U;
            assert(test_tabel[i] == v.by!E);
        }
    }

    { // utc test,
        static assert(Value.asType!utc_t is Type.UTC);
        utc_t time = 1234;
        Value v;
        v = time;
        assert(v.by!(Type.UTC) == 1234);
        alias U = Value.TypeT!(Type.UTC);
        static assert(is(U == const utc_t));
        static assert(!is(U == const ulong));
    }

    { // data arrays
        alias Tabel=Tuple!(
            immutable(ubyte)[], immutable(bool)[], immutable(int)[], immutable(uint)[],
            immutable(long)[], immutable(ulong)[], immutable(float)[], immutable(double)[]
            );
        Tabel test_tabel;
        test_tabel[0]=[1, 2, 3];
        test_tabel[1]=[false, true, true];
        test_tabel[2]=[-1, 7, -42];
        test_tabel[3]=[1, 7, 42];
        test_tabel[4]=[-1, 7, -42_000_000_000_000];
        test_tabel[5]=[1, 7, 42_000_000_000_000];
        test_tabel[6]=[-1.7, 7, 42.42e10];
        test_tabel[7]=[1.7, -7, 42,42e207];

        foreach(i, t; test_tabel) {
            Value v;
            v=t;
            alias U = test_tabel.Types[i];
            enum  E = Value.asType!U;
            static assert(is(const U == Value.TypeT!E));
            assert(t == v.by!E);
            assert(t.length == v.by!E.length);
            assert(t is v.by!E);
        }
    }
}


@safe bool is_index(string a, out uint result) pure {
    import std.conv : to;
    enum MAX_UINT_SIZE=to!string(uint.max).length;
    if ( a.length <= MAX_UINT_SIZE ) {
        if ( (a[0] is '0') && (a.length > 1) ) {
            return false;
        }
        foreach(c; a) {
            if ( (c < '0') || (c > '9') ) {
                return false;
            }
        }
        immutable number=a.to!ulong;
        if ( number <= uint.max ) {
            result = cast(uint)number;
            return true;
        }
    }
    return false;
}

unittest { // check is_index
    import std.conv : to;
    uint index;
    assert(is_index("0", index));
    assert(index is 0);
    assert(!is_index("-1", index));
    assert(is_index(uint.max.to!string, index));
    assert(index is uint.max);

    assert(!is_index(((cast(ulong)uint.max)+1).to!string, index));

    assert(is_index("42", index));
    assert(index is 42);

    assert(!is_index("0x0", index));
    assert(!is_index("00", index));
    assert(!is_index("01", index));
}

@safe bool less_than(string a, string b) pure
    in {
        assert(a.length > 0);
        assert(b.length > 0);
    }
body {
    uint a_index;
    uint b_index;
    if ( is_index(a, a_index) && is_index(b, b_index) ) {
        return a_index < b_index;
    }
    return a < b;
}

unittest { // Check less_than
    import std.conv : to;
    assert(less_than("a", "b"));
    assert(less_than(0.to!string, 1.to!string));
    assert(!less_than("00", "0"));
    assert(less_than("0", "abe"));
}

@safe bool is_key_valid(string a) pure nothrow {
    enum : char {
        SPACE = 0x20,
            DEL = 0x7F,
            DOUBLE_QUOTE = 34,
            QUOTE = 39,
            BACK_QUOTE = 0x60
            }
    if ( (a.length > 0) && (a.length <= ubyte.max) ) {
        foreach(c; a) {
            // Chars between SPACE and DEL is valid
            // except for " ' ` is not valid
            if ( (c <= SPACE) || (c >= DEL) ||
                ( c == DOUBLE_QUOTE ) || ( c == QUOTE ) ||
                ( c == BACK_QUOTE ) ) {
                return false;
            }
        }
        return true;
    }
    return false;
}

unittest { // Check is_key_valid
    import std.conv : to;
    import std.range : iota;
    import std.algorithm.iteration : map, each;

    assert(!is_key_valid(""));
    string text=" "; // SPACE
    assert(!is_key_valid(text));
    text=[0x80]; // Only simple ASCII
    assert(!is_key_valid(text));
    text=[char(34)]; // Double quote
    assert(!is_key_valid(text));
    text="'"; // Sigle quote
    assert(!is_key_valid(text));
    text="`"; // Back quote
    assert(!is_key_valid(text));
    text="\0";
    assert(!is_key_valid(text));


    assert(is_key_valid("abc"));
    assert(is_key_valid(42.to!string));

    text="";
    iota(0,ubyte.max).each!((i) => text~='a');
    assert(is_key_valid(text));
    text~='B';
    assert(!is_key_valid(text));
}

@safe
void array_write(T)(ref ubyte[] buffer, T array, ref size_t index) pure if ( is(T : U[], U) && isBasicType!U ) {
    const ubytes = cast(const(ubyte[]))array;
    immutable new_index = index + ubytes.length;
    scope(success) {
        index = new_index;
    }
    buffer[index..new_index] = ubytes;
}
