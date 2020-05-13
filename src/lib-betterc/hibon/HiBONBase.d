module hibon.HiBONBase;

extern(C):
@nogc:


import std.meta : AliasSeq;
import std.traits : isBasicType, isSomeString, isIntegral, isNumeric, isType, Unqual, getUDAs, hasUDA;

import std.system : Endian;
// import std.exception;
import core.stdc.stdio;

import hibon.utils.BinBuffer;
import hibon.BigNumber;
import hibon.utils.Bailout;
import hibon.utils.Memory;
import hibon.utils.utc;

/++
 HiBON Type codes
+/
enum Type : ubyte {
    NONE            = 0x00,  /// End Of Document
        FLOAT64         = 0x01,  /// Floating point
        STRING          = 0x02,  /// UTF8 STRING
        DOCUMENT        = 0x03,  /// Embedded document (Both Object and Documents)
        BOOLEAN         = 0x08,  /// Boolean - true or false
        UTC             = 0x09,  /// UTC datetime
        INT32           = 0x10,  /// 32-bit integer
        INT64           = 0x12,  /// 64-bit integer,
        //       FLOAT128        = 0x13, /// Decimal 128bits
        BIGINT          = 0x1B,  /// Signed Bigint

        UINT32          = 0x20,  // 32 bit unsigend integer
        FLOAT32         = 0x21,  // 32 bit Float
        UINT64          = 0x22,  // 64 bit unsigned integer
//        HASHDOC         = 0x23,  // Hash point to documement
//        UBIGINT         = 0x2B,  /// Unsigned Bigint

        DEFINED_NATIVE  = 0x40,  /// Reserved as a definition tag it's for Native types
        NATIVE_DOCUMENT = DEFINED_NATIVE | 0x3e, /// This type is only used as an internal represention (Document type)

        DEFINED_ARRAY   = 0x80,  // Indicated an Intrinsic array types
        BINARY          = DEFINED_ARRAY | 0x05, /// Binary data
        INT32_ARRAY     = DEFINED_ARRAY | INT32, /// 32bit integer array (int[])
        INT64_ARRAY     = DEFINED_ARRAY | INT64, /// 64bit integer array (long[])
        FLOAT64_ARRAY   = DEFINED_ARRAY | FLOAT64, /// 64bit floating point array (double[])
        BOOLEAN_ARRAY   = DEFINED_ARRAY | BOOLEAN, /// boolean array (bool[])
        UINT32_ARRAY    = DEFINED_ARRAY | UINT32,  /// Unsigned 32bit integer array (uint[])
        UINT64_ARRAY    = DEFINED_ARRAY | UINT64,  /// Unsigned 64bit integer array (uint[])
        FLOAT32_ARRAY   = DEFINED_ARRAY | FLOAT32, /// 64bit floating point array (double[])
        //     FLOAT128_ARRAY   = DEFINED_ARRAY | FLOAT128,

        /// Native types is only used inside the BSON object
        NATIVE_HIBON_ARRAY    = DEFINED_ARRAY | DEFINED_NATIVE | DOCUMENT,
        /// Represetents (HISON[]) is convert to an ARRAY of DOCUMENT's
        NATIVE_DOCUMENT_ARRAY = DEFINED_ARRAY | DEFINED_NATIVE | NATIVE_DOCUMENT,
        /// Represetents (Document[]) is convert to an ARRAY of DOCUMENT's
        NATIVE_STRING_ARRAY   = DEFINED_ARRAY | DEFINED_NATIVE | STRING,
        /// Represetents (string[]) is convert to an ARRAY of string's
        }

/++
 Returns:
 true if the type is a internal native HiBON type
+/
bool isNative(Type type) pure nothrow {
    with(Type) {
        return ((type & DEFINED_NATIVE) !is 0) && (type !is DEFINED_NATIVE);
    }
}



/++
 Returns:
 true if the type is a internal native array HiBON type
+/
bool isNativeArray(Type type) pure nothrow {
    with(Type) {
        return ((type & DEFINED_ARRAY) !is 0) && (isNative(type));
    }
}

/++
 Returns:
 true if the type is a HiBON data array (This is not the same as HiBON.isArray)
+/
bool isArray(Type type) pure nothrow {
    with(Type) {
        return ((type & DEFINED_ARRAY) !is 0) && (type !is DEFINED_ARRAY) && (!isNative(type));
    }
}

mixin(Init_HiBON_Types!("__gshared immutable hibon_types=", 0));

/++
 Returns:
 true if the type is a valid HiBONType excluding narive types
+/
bool isHiBONType(Type type) {
    return hibon_types[type];
}

template Init_HiBON_Types(string text, uint i) {
    static if(i is ubyte.max+1) {
        enum Init_HiBON_Types=text~"];";
    }
    else {
        enum start_bracket=(i is 0)?"[":"";
        enum E=cast(Type)i;
        enum flag=(!isNative(E) && (E !is Type.NONE) && (E !is Type.DEFINED_ARRAY) && (E !is Type.DEFINED_NATIVE));
        enum Init_HiBON_Types=Init_HiBON_Types!(text~start_bracket~flag.stringof~",", i+1);
    }
}



///
version(none)
static unittest {
    with(Type) {
        static assert(!isHiBONType(NONE));
        static assert(!isHiBONType(DEFINED_ARRAY));
        static assert(!isHiBONType(DEFINED_NATIVE));
    }

}

version(none) {

enum isBasicValueType(T) = isBasicType!T || is(T : decimal_t);
}
/++
 HiBON Generic value used by the HiBON class and the Document struct
+/
//@safe
union ValueT(bool NATIVE=false, HiBON,  Document) {
    @nogc:
    @Type(Type.FLOAT32)   float     float32;
    @Type(Type.FLOAT64)   double    float64;
    // @Type(Type.FLOAT128)  decimal_t float128;
    @Type(Type.STRING)    string    text;
    @Type(Type.BOOLEAN)   bool      boolean;
    //  @Type(Type.LIST)
    static if ( !is(HiBON == void ) ) {
        @Type(Type.DOCUMENT)  HiBON      document;
        void dispose() {
            printf("VALUE Dispose\n");
        }
    }
    else static if ( !is(Document == void ) ) {
        @Type(Type.DOCUMENT)  Document      document;
    }
    @Type(Type.UTC)       utc_t     date;
    @Type(Type.INT32)     int       int32;
    @Type(Type.INT64)     long      int64;
    @Type(Type.UINT32)    uint      uint32;
    @Type(Type.UINT64)    ulong     uint64;
    @Type(Type.BIGINT)    BigNumber bigint;

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
            enum GetFunctions=text~"else {\n    static assert(0, \"Not support illegal \"); \n}";
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
                    enum code_else=(first)?"":"else ";
                    enum code = code_else~"static if ( type is "~MemberType.stringof~" ) {\n    return "~name~";\n}\n";
                }
                enum GetFunctions=GetFunctions!(text~code, false, TList[1..$]);
            }
            else {
                enum GetFunctions=GetFunctions!(text, false, TList[1..$]);
            }
        }

    }

    /++
     Returns:
     the value as HiBON type E
     +/
    auto by(Type type)() pure const {
        enum code=GetFunctions!("", true, __traits(allMembers, ValueT));
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

    /++
     convert the T to a HiBON-Type
     +/
    enum asType(T) = GetType!(Unqual!T, __traits(allMembers, ValueT));

    /++
     is true if the type T is support by the HiBON
     +/
    enum hasType(T) = asType!T !is Type.NONE;

    static if (!is(Document == void) && is(HiBON == void)) {
            this(Document doc) {
            document = doc;
        }
    }

    static if (!is(Document == void) && !is(HiBON == void) ) {
            this(Document doc) {
            native_document = doc;
        }
    }

    /++
     Construct a Value of the type T
     +/
    this(T)(T x) if (isOneOf!(Unqual!T, typeof(this.tupleof)) && !is(T == struct) ) {
        alias MutableT = Unqual!T;
        static foreach(m; __traits(allMembers, ValueT) ) {
            static if ( is(typeof(__traits(getMember, this, m)) == MutableT ) ){
                enum code="alias member=ValueT."~m~";";
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
        assert (0, T.stringof~" is not supported" );
    }

    /++
     Constructs a Value of the type BigNumber
     +/
    this(BigNumber big) {
        bigint=big;
    }

    /++
     Assign the value to x
     Params:
     x = value to be assigned
     +/
    void opAssign(T)(T x) if (isOneOf!(T, typeof(this.tupleof))) {
        alias UnqualT = Unqual!T;
        static foreach(m; __traits(allMembers, ValueT) ) {
            static if ( is(typeof(__traits(getMember, this, m)) == T ) ){
                static if ( (is(T == struct) || is(T == class)) && !__traits(compiles, __traits(getMember, this, m) = x) ) {
                    enum code="alias member=ValueT."~m~";";
                    mixin(code);
                    enum MemberType=getUDAs!(member, Type)[0];
                    static assert ( MemberType !is Type.NONE, T.stringof~" is not supported" );
                    x.copy(__traits(getMember, this, m));
                }
                else {
                    __traits(getMember, this, m) = cast(UnqualT)x;
                }
            }
        }
    }


    /++
     List if valud cast-types
     +/
    alias CastTypes=AliasSeq!(uint, int, ulong, long, float, double, string);

    /++
     Assign of none standard HiBON types.
     This function will cast to type has the best match to the parameter x
     Params:
     x = sign value
     +/
    void opAssign(T)(T x) if (!isOneOf!(T, typeof(this.tupleof))) {
        alias UnqualT=Unqual!T;
        alias CastT=castTo!(UnqualT, CastTypes);
        static assert(is(CastT==void), "Type "~T.stringof~" not supported");
        alias E=asType!UnqualT;
        opAssing(cast(CastT)x);
    }

    /++
     Convert a HiBON Type to a D-type
     +/
    alias TypeT(Type aType) = typeof(by!aType());

    /++
     Returns:
     the size on bytes of the value as a HiBON type E
     +/
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
                static assert(0, "Type "~E.stringof~" of "~T.stringof~" is not defined");
            }
        }
        else {
            static assert(0, "Illegal type "~E.stringof);
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

        utc_t time = utc_t(1234UL);
        Value v;
        v = time;
        assert(v.by!(Type.UTC) == 1234UL);
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
        immutable(ubyte[3]) test_tabel_0_=[1, 2, 3];
        test_tabel[0]=test_tabel_0_;
        immutable(bool[3]) test_tabel_1_=[false, true, true];
        test_tabel[1]=test_tabel_1_;
        immutable(int[3]) test_tabel_2_=[-1, 7, -42];
        test_tabel[2]=test_tabel_2_;
        immutable(uint[3]) test_tabel_3_=[1, 7, 42];
        test_tabel[3]=test_tabel_3_;
        immutable(long[3]) test_tabel_4_=[-1, 7, -42_000_000_000_000];
        test_tabel[4]=test_tabel_4_;
        immutable(ulong[3]) test_tabel_5_=[1, 7, 42_000_000_000_000];
        test_tabel[5]=test_tabel_5_;
        immutable(float[3]) test_tabel_6_=[-1.7, 7, 42.42e10];
        test_tabel[6]=test_tabel_6_;
        immutable(double[3]) test_tabel_7_=[1.7, -7, 42.42e207];
        test_tabel[7]=test_tabel_7_;

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

/++
 Converts from a text to a index
 Params:
 a = the string to be converted to an index
 result = index value
 Returns:
 true if the a is an index
+/
// memcpy(return void* s1, scope const void* s2, size_t n);
bool is_index(const(char[]) a, out uint result) pure {
    enum MAX_UINT_SIZE=uint.max.stringof.length;
    if ( a.length <= MAX_UINT_SIZE ) {
        if ( (a[0] is '0') && (a.length > 1) ) {
            return false;
        }
        foreach(c; a) {
            if ( (c < '0') || (c > '9') ) {
                return false;
            }
        }
        immutable number=a.to_ulong;
        if ( number <= uint.max ) {
            result = cast(uint)number;
            return true;
        }
    }
    return false;
}

ulong to_ulong(const(char[]) num) pure {
    ulong result;
    foreach(a; num) {
        result*=10;
        result+=(a-'0');
    }
    return result;
}

uint to_uint(string num) pure {
    ulong result=to_ulong(num);
//    .check(result <= uint.max, "Bad uint overflow");
    return cast(uint)result;
}


/++
 Check if all the keys in range is indices and are consecutive
 Returns:
 true if keys is the indices of an HiBON array
+/
version(none)
bool isArray(R)(R keys) {
    bool check_array_index(const uint previous_index) {
        if (!keys.empty) {
            uint current_index;
            if (is_index(keys.front, current_index)) {
                if (previous_index+1 is current_index) {
                    keys.popFront;
                    return check_array_index(current_index);
                }
            }
            return false;
        }
        return true;
    }
    if (!keys.empty) {
        uint previous_index=uint.max;
        if (is_index(keys.front, previous_index) && (previous_index is 0)) {
            keys.popFront;
            return check_array_index(previous_index);
        }
    }
    return false;
}

///
unittest { // check is_index
    uint index;
    assert(is_index("0", index));
    assert(index is 0);
    assert(!is_index("-1", index));

    assert(is_index(uint.max.stringof[0..$-1], index));
    assert(index is uint.max);

    enum overflow=((cast(ulong)uint.max)+1);
    assert(!is_index(overflow.stringof, index));

    assert(is_index("42", index));
    assert(index is 42);

    assert(!is_index("0x0", index));
    assert(!is_index("00", index));
    assert(!is_index("01", index));
}

/++
 This function decides the order of the HiBON keys
+/
int key_compare(const(char[]) a, const(char[]) b) pure
    in {
        assert(a.length > 0);
        assert(b.length > 0);
    }
body {
    uint a_index;
    uint b_index;
    if ( is_index(a, a_index) && is_index(b, b_index) ) {
        if (a_index < b_index) {
            return -1;
        }
        else if (a_index == b_index) {
            return 0;
        }
        return 1;
    }
    if (a == b) {
        return 0;
    }
    else if (a < b) {
        return -1;
    }
    return 1;
}

///
unittest { // Check less_than
    assert(key_compare("a", "b") < 0);
    assert(key_compare("0", "1") < 0);
    assert(key_compare("00", "0") > 0);
    assert(key_compare("0", "abe") < 0);
    assert(key_compare("42", "abe") < 0);
    assert(key_compare("42", "17") > 0);
    assert(key_compare("42", "42") == 0);
    assert(key_compare("abc", "abc") == 0);
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

///
unittest { // Check is_key_valid
    assert(!is_key_valid(""));
    string text=" "; // SPACE
    assert(!is_key_valid(text));
    text="\x80"; // Only simple ASCII
    assert(!is_key_valid(text));
    text="\""; // Double quote
    assert(!is_key_valid(text));
    text="'"; // Sigle quote
    assert(!is_key_valid(text));
    text="`"; // Back quote
    assert(!is_key_valid(text));
    text="\0";
    assert(!is_key_valid(text));


    assert(is_key_valid("abc"));
    assert(is_key_valid("42"));

    text="";
    char[ubyte.max+1] max_key_size;
    foreach(ref a; max_key_size) {
        a='a';
    }
    assert(is_key_valid(max_key_size[0..$-1]));
    assert(!is_key_valid(max_key_size));
}


template isOneOf(T, TList...) {
    static if ( TList.length == 0 ) {
        enum isOneOf = false;
    }
    else static if (is(T == TList[0])) {
        enum isOneOf = true;
    }
    else {
        alias isOneOf = isOneOf!(T, TList[1..$]);
    }
}
