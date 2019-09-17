// Written in the D programming language.

/**
 * BSON spec implementation
 *
 * See_Also:
 *  $(LINK2 http://bsonspec.org/, BSON - Binary JSON)
 *
 * Copyright: Copyright Masahiro Nakagawa 2011-.
 * License:   <a href="http://www.apache.org/licenses/">Apache LICENSE Version 2.0</a>.
 * Authors:   Masahiro Nakagawa
 * Modified   Carsten Bleser Rasmussen
 *            BSON serialize function added
 *            HBSON functions added
 *
 *            Copyright Masahiro Nakagawa 2011-.
 *    Distributed under the Apache LICENSE Version 2.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *            http://www.apache.org/licenses/)
 */
module tagion.utils.HBSON;

/*
  import core.stdc.string;  // Some operations in Phobos not safe, pure and nothrow, e.g. cmp

  import std.algorithm;
  import std.conv;
  import std.exception;  // assumeUnique
  import std.datetime;   // Date, DateTime
  import std.typecons;   // Tuple
  import std.format;
  import std.traits : isSomeString, isIntegral, isArray;
  import std.algorithm.searching : maxElement;
//import std.array : Appender;
private import std.bitmanip;
import std.meta : AliasSeq;
//import std.stdio;

import tagion.utils.Miscellaneous : toHexString;
*/

import std.datetime;   // Date, DateTime
import tagion.utils.Document;
import tagion.TagionExceptions : Check, TagionException;



/**
 * Exception type used by tagion.utils.BSON module
 */
@safe
class HBSONException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

alias check=Check!HBSONException;


//
// D doesn't support 128bits floating point yet so this is
// Standin for decimal type 128bits floating point
struct decimal {
    long x, y;
}


//private:


// Phobos does not have 0-filled hex conversion functions?


@trusted
string toHex(in ubyte[] nums) pure nothrow {
    immutable static lowerHexDigits = "0123456789abcdef";

    char[] result = new char[](nums.length * 2);
    foreach (i, num; nums) {
        immutable index = i * 2;
        result[index]     = lowerHexDigits[(num & 0xf0) >> 4];
        result[index + 1] = lowerHexDigits[num & 0x0f];
    }

    return assumeUnique(result);
}


@safe
ubyte[] fromHex(in string hex) pure nothrow {
    static ubyte toNum(in char c) pure nothrow
    {
        if ('0' <= c && c <= '9')
            return cast(ubyte)(c - '0');
        if ('a' <= c && c <= 'f')
            return cast(ubyte)(c - 'a' + 10);
        assert(false, "Out of hex: " ~ c);
    }

    ubyte[] result = new ubyte[](hex.length / 2);

    foreach (i, ref num; result) {
        immutable index = i * 2;
        num = cast(ubyte)((toNum(hex[index]) << 4) | toNum(hex[index + 1]));
    }

    return result;
}


bool isSubType(T)() {
    return (is(T:const(bool)[]))||
        (is(T:const(ubyte)[])) ||
        (is(T:const(int)[])) ||
        (is(T:const(uint)[])) ||
        (is(T:const(long)[])) ||
        (is(T:const(ulong)[])) ||
        (is(T:const(double)[])) ||
        (is(T:const(float)[])) ||
        (is(T:const(decimal)[]));
}

template getSubtype(T)() {
    alias BaseT=TypedefType!T;
    alias UnqualT=Unqual!BaseT;
    static if ( is(UnqualT:U[], U) ) {
        static assert(is(U == immutable), foramt("Only array with immutable elements is support not '%s'", T.stringof));
        static if ( is(UnqualT == bool) ) {
            alias getSubType=Type.BOOLEAN;
        }
        else static if ( is(UnqualT == double) ) {
            alias getSubType=Type.DOUBLE;
        }
        else static if ( is(UnqualT == float) ) {
            alias getSubType=Type.FLOAT;
        }
        else static if ( is(UnqualT == int) ) {
            alias getSubType=Type.INT32;
        }
        else static if ( is(UnqualT == long) ) {
            alias getSubType=Type.INT64;
        }
        else static if ( is(UnqualT == uint) ) {
            alias getSubType=Type.UINT32;
        }
        else static if ( is(UnqualT == ulong) ) {
            alias getSubType=Type.UINT64;
        }
        else static if ( is(UnqualT == string) ) {
            alias getSubType=Type.STRING;
        }
        else static if ( is(UnqualT == Date) ) {
            alias getSubType=Type.DATE;
        }
    }
    else {
        static assert(0, format("Unsupported type '%s'", T.stringof));
    }
}

template getType(T) {
    alias BaseT=TypedefType!T;
    alias UnqualT=Unqual!BaseT;
    static if ( is(UnqualT == bool) ) {
        alias getType=Type.BOOLEAN;
    }
    else static if ( is(UnqualT == double) ) {
        alias getType=Type.DOUBLE;
    }
    else static if ( is(UnqualT == float) ) {
        alias getType=Type.FLOAT;
    }
    else static if ( is(UnqualT == int) ) {
        alias getType=Type.INT32;
    }
    else static if ( is(UnqualT == long) ) {
        alias getType=Type.INT64;
    }
    else static if ( is(UnqualT == uint) ) {
        alias getType=Type.UINT32;
    }
    else static if ( is(UnqualT == ulong) ) {
        alias getType=Type.UINT64;
    }
    else static if ( is(UnqualT == string) ) {
        alias getType=Type.STRING;
    }
    else static if ( is(UnqualT == Date) ) {
        alias getType=Type.DATE;
    }
    else static if ( is(UnqualT == Document) ) {
        alias getType=Type.NATIVE_DOCUMENT;
    }
    else static if ( is(UnqualT == Document[]) ) {
        alias getType=Type.NATIVE_DOCUMENT_ARRAY;
    }
    else static if ( is(UnqualT == HBSON[]) ) {
        alias getType=Type.NATIVE_BSON_ARRAY;
    }
    else static if ( is(UnqualT:U[], U) ) {
        static assert(is(U == immutable), foramt("Only array with immutable elements is support not '%s'", T.stringof));
        alias getType=Type.NATIVE_BSON_ARRAY;
    }
    else {
        static assert(0, format("Unsupported type '%s'", T.stringof));
    }
}

unittest
{
    static struct Test {
        ubyte[] source;
        string  answer;
    }

    Test[] tests = [
        Test([0x00], "00"), Test([0xff, 0xff], "ffff"),
        Test([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde], "123456789abcde")
        ];

    foreach (ref test; tests)
        assert(test.source.toHex() == test.answer);
    foreach (ref test; tests)
        assert(fromHex(test.answer) == test.source);
}


unittest { // toArray
    auto strings=["Hej", "med", "Dig"];
    auto hbson=new HBSON;

    hbson[strings.stringof]=strings;

    auto doc=Document(hbson.serialize);
    auto same=doc[strings.stringof].toArray!string;

    assert(same == strings);
}

//
// HBSON Array
//
alias HBSAN=HBSON!(true);

@safe class HBSON(bool hbson_array=false, bool one_time_write=false) {

    static string TypeString(T)() {
        alias BaseT=TypedefType!T;
        alias Buffer=immutable(ubyte)[];
        alias HBSONType=DtoHBSONType!(BaseT);

        static if ( !is(HBSONType==bool) ) {
            return HBSONType.stringof;
        }
        else static if (
            is(BaseT:const(HBSON)) ||
            is(BaseT:Document[]) ||
            is(BaseT:const(HBSON)[]) ||
            is(BaseT:string[]) ||
            is(BaseT:Buffer[]) ) {
            return BaseT.stringof;
        }
        else {
            static assert(0, format("Type %s does not have a HBSON equivalent type", T.stringof));
//            return DtoHBSONType!(BaseT).stringof;
        }
    }


    package Type _type;
    package BinarySubType _subtype;
    struct Member {
        string key;
        HBSON element;
    }
    alias Members=RedBlackTree!(immutable(Member), "less_than(a.key, b.key)");
    protected Members _members;
//    redBlackTree!("a.begin_index < b.begin_index")(recycle_segments[]);
//    alias red
//    private HBSON members; // List of members
//    private string[] _key;
//    public bool typedarray; // Start standard type array as Binary data (like double[])
    public bool no_duble; // This will prevent the HBSON object from creating double or multiple members
//     string key() @safe pure nothrow const {
// //        assert(0, "Not implemented Yet");
//         return _key;
//     }

//     private _key;
    union Value {
        double number;
        float number32;
        string text;
        bool boolean;
        HBSON document;
        ulong date;
        int int32;
        long int64;
        uint uint32;
        ulong uint64;
//        immutable(char)[][2] regex;
//        CodeScope codescope;
        immutable(ubyte)[] binary;
        immutable(bool)[] bool_array;
        immutable(int)[] int32_array;
        immutable(uint)[] uint32_array;
        immutable(long)[] int64_array;
        immutable(ulong)[] uint64_array;
        immutable(float)[] float_array;
        immutable(double)[] double_array;
        immutable(decimal)[] decimal_array;
        HBSON[] hbson_array;
        Document[] document_array;
    };
    this() {
        _type=Type.DOCUMENT;
    }

    @property
    // @trusted
    // size_t id() const pure nothrow {
    //     return cast(size_t)(cast(void*)this);
    // }

    void check_type(DTYPE)(string file = __FILE__, size_t line = __LINE__ ){
        enum type_to_be_check=DtoHBSONType!DTYPE;
        static if ( is(typeof(type_to_be_check) == BinarySubType ) ) {
            check(_type == Type.BINARY, format("Bad type %s expected %s", Type.BINARY, _type), file, line);
//            check(_subtype == Type.BINARY, format("Bad type %s expected %s", Type.BINARY, _type), file, line);
            check(_subtype == type_to_be_check, format("Bad sub-type %s expected %s", type_to_be_check, _subtype), file, line);

        }
        else {
            check(_type == type_to_be_check, format("Bad type %s expected %s", type_to_be_check, _type), file, line);
        }
    }

    @trusted
    auto get(T)() inout {
        alias BaseT=TypedefType!T;
        alias UnqualT=Unqual!BaseT;
        static if (is(UnqualT == double)) {
            check!UnqualT;
//                assert(_type == Type.DOUBLE);
            return cast(T)(value.number);
        }
        else static if (is(UnqualT == string)) {
            check!UnqualT;
//            assert(_type == Type.STRING);
            return cast(T)(value.text);
        }
        else static if (is(UnqualT == bool)) {
            check!UnqualT;

//            assert(_type == Type.BOOLEAN);
            return cast(T)(value.boolean);
        }
        else static if (is(BaseT:const(HBSON))) {

            assert(_type == Type.DOCUMENT);
            return cast(T)(value.document);
        }
        else static if (is(BaseT:const(Document))) {
            assert(_type == Type.NATIVE_DOCUMENT);
            return Document(assumeUnique(value.binary));
        }
        /*
        else static if (is(BaseT==ObjectId)) {
            assert(_type == Type.OID);
            return cast(T)(value.oid);
        }
        */
        else static if (is(UnqualT == int)) {
            check!UnqualT;
//            assert(_type == Type.INT32);
            return cast(T)(value.int32);
        }
        else static if (is(UnqualT  == uint)) {
            check!UnqualT;
//            assert(_type == Type.UINT32);
            return cast(T)(value.uint32);
        }
        else static if (is(UnqualT == long)) {
            check!UnqualT;
//            assert(_type == Type.INT64);
            return cast(T)(value.int64);
        }
        else static if (is(UnqualT == ulong)) {
            check!UnqualT;
//            assert(_type == Type.UINT64);
            return cast(T)(value.uint64);
        }
        else static if (is(BaseT==Date)) {
            check!UnqualT;
            assert(_type == Type.DATE);
            return cast(T)(value.date);
        }
        // else static if (is(BaseT==CodeScope)) {
        //     assert(_type == Type.JS_CODE_SCOPE);
        //     return cast(T)(value.codescope);
        // }
        /*
        else static if (is(BaseT:string[])) {
            assert(_type == Type.NATIVE_STRING_ARRAY);
            return cast(T)(value.text_array);
        }
        */
        else static if ( is(UnqualT : immutable(ubyte[])) ) {
            check!UnqualT;
//            assert(_type == Type.BINARY);
            return cast(T)(value.binary);
        }
        else static if (is(UnqualT  : immutable(bool[])) ) {
            check!UnqualT;
//            assert(_type == Type.ARRAY);
//            assert(subtype == BinarySubType.BOOLEAN_array);
            return cast(T)(value.bool_array);
        }
        else static if (is(UnqualT : immutable(int)[])) {
            check!UnqualT;
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.INT32_array);
            return cast(T)(value.int32_array);
        }
        else static if (is(UnqualT : immutable(uint[]))) {
            check!UnqualT;
            // assert(_type == Type.ARRAY);
            // assert(subtype == BinarySubType.UINT32_array);
            return cast(T)(value.uint32_array);
        }
        else static if (is(UnqualT : immutable(ulong[]))) {
            check!UnqualT;
            // assert(_type == Type.ARRAY);
            // assert(subtype == BinarySubType.UINT64_array);
            return cast(T)(value.uint64_array);
        }
        else static if (is(UnqualT : immutable(long[]))) {
            check!UnqualT;
            // assert(_type == Type.ARRAY);
            // assert(subtype == BinarySubType.INT64_array);
            return cast(T)(value.int64_array);
        }
        else static if (is(UnqualT : immutable(float[]))) {
            check!UnqualT;
            // assert(_type == Type.ARRAY);
            // assert(subtype == BinarySubType.FLOAT_array);
            return cast(T)(value.float_array);
        }
        else static if (is(UnqualT : immutable(double[]))) {
            check!UnqualT;
            // assert(_type == Type.ARRAY);
            // assert(subtype == BinarySubType.DOUBLE_array);
            return cast(T)(value.double_array);
        }
        else static if (is(UnqualT : immutable(decimal[]))) {
            check!UnqualT;
            // assert(_type == Type.ARRAY);
            // assert(subtype == BinarySubType.DOUBLE_array);
            return cast(T)(value.double_array);
        }
        // else static if (is(BaseT:U[],U) && isSomeString!U) {
        //     assert(_type == Type.ARRAY);
        //     assert(subtype == BinarySubType.STRING_array);
        //     return cast(T)(value.text_array);
        // }
        else static if (is(BaseT==HBSON[])) {
            check(_type == Type.NATIVE_HBSON_ARRAY, format("%s is not compatible with %s type", BaseT.stringof, _type));
//            assert(_type == Type.NATIVE_HBSON_ARRAY);
            return cast(T)(value.hbson_array);
        }
        else static if (is(BaseT==Document[])) {
            check(_type == Type.NATIVE_DOCUMENT_ARRAY, format("%s is not compatible with %s type", BaseT.stringof, _type));
//            assert(_type == Type.NATIVE_ARRAY);
            return cast(T)(value.document_array);
        }
        else {
            static if ( !isSomeString!T && is(T:U[]) && !is(U == immutable) ) {
                static assert(0, format("Only immutable array is supported not %s", T.stringof));
            }
            static assert(0, format("Type %s is not supported by this function",T.stringof));
        }


    }
    package Value value;
    bool isDocument() {
        return ( (type == Type.DOCUMENT) || (type == Type.ARRAY) );
    }

    void append(T)(string key, T x) {
        alias BaseT=TypedefType!T;
        alias UnqualT=Unqual!BaseT;
        HBSON elm=new HBSON;
        scope(success) {
            // elm._type=type;
            // elm._subtype=binary_subtype;
            Member member={key : key, element : elm};
            _member.insert(member);
            // elm._key=key;
            // elm.members=members;
            // members=elm;
        }
        static if ( is(UnqualT == bool) ) {
            elm._type=Type.BOOLEAN;
            elm.value.boolean=x;
        }
        else static if ( is(UnqualT == double) ) {
        }
    /*
    @trusted
    protected void append(T)(Type type, string key, T x, BinarySubType binary_subtype=BinarySubType.GENERIC) {
        alias BaseT=TypedefType!T;
        alias UnqualT=Unqual!BaseT;
        check(!hasElement(key), format("Member '%s' already exist", key));
        bool result=false;
        HBSON elm=new HBSON;
        scope(success) {
            elm._type=type;
            elm._subtype=binary_subtype;
            Member member={key : key, element : elm};
            _member.insert(member);
            // elm._key=key;
            // elm.members=members;
            // members=elm;
        }
        with (Type) {
            final switch (type) {
            case MIN:
            case NONE:
            case MAX:
            case TRUNC:
                break;
            case HASHDOC:
                assert(0, "Hashdoc not implemented yet");
                break;
            case DOUBLE:
                elm.value.number=x;
                result=true;
                break
            case FLOAT:
                elm.value.number32=x;
                result=true;
                break;
            case STRING:
                elm.value.text=x;
                result=true;
                break;
            case DOCUMENT:
                static if (is(BaseT:HBSON)) {
                    elm.value.document=x;
                    result=true;
                }
                else static if (is(BaseT:const(HBSON))) {
                    elm.value.document=cast(HBSON)x;
                    result=true;
                }
                else {
                    .check(0, "Unsupported type "~T.stringof~" not a valid "~to!string(type));
                }
                break;
            case ARRAY:
                static if (is(BaseT==HBSON)) {
                    elm.value.document=x;
                    result=true;
                }
                else static if (is(BaseT:const(HBSON))) {
                    elm.value.document=cast(HBSON)x;
                    result=true;
                }
                else static if (is(BaseT:U[],U) && !isSomeString!BaseT && !isSubType!BaseT && !is(U==struct) ) {
                    auto hbson_array=new HBSON;
                    foreach(i, ref b; x) {
                        if ( b !is null ) {
                            hbson_array[i]=b;
                        }
                    }
                    elm.value.document=hbson_array;
                    result=true;
                }
                else {
                    assert(0, "Unsupported type "~T.stringof~" does not seem to be a valid native array");
                }

                break;
            case BINARY:
                static if (is(BaseT:U[],U)) {
                    alias UnqualU=Unqual!U;
                    static if (is(UnqualU == immutable ubyte)) {
                        elm.value.binary=cast(BaseT)x;
                    }
                    else static if (is(UnqualU == immutable int)) {
                        elm.value.int32_array=cast(BaseT)x;
                    }
                    else static if (is(UnqualU == immutable uint)) {
                        elm.value.uint32_array=cast(BaseT)x;
                    }
                    else static if (is(UnqualU == immutable long)) {
                        elm.value.int64_array=cast(BaseT)x;
                    }
                    else static if (is(UnqualU ==immutable ulong)) {
                        elm.value.uint64_array=cast(BaseT)x;
                    }
                    else static if (is(UnqualU == immutable double)) {
                        elm.value.double_array=cast(BaseT)x;
                    }
                    else static if (is(UnqualU == immutable float)) {
                        elm.value.float_array=cast(BaseT)x;
                    }
                    else static if (is(UnqualU == immutable decimal)) {
                        elm.value.float_array=cast(BaseT)x;
                    }
                    else static if (is(UnqualU == immutable bool)) {
                        elm.value.bool_array=cast(BaseT)x;
                    }
                    else {
                        assert(0, "Native array must be immutable not "~T.stringof);
                    }
                }
                else {
                    static if (__traits(compiles,x.ptr)) {
                        elm.value.binary=((cast(ubyte*)x.ptr)[0..BaseT.sizeof]).idup;
                    }
                    else {
                        elm.value.binary=((cast(ubyte*)&x)[0..BaseT.sizeof]).idup;
                    }
                    elm.subtype=BinarySubType.userDefined;
                }
                result=true;
                break;
            case BOOLEAN:
                elm.value.boolean=x;
                result=true;
                break;
            case DATE:
                static if (is(BaseT:Date)) {
                    elm.value.date=x;
                    result=true;
                }
                break;
            case NULL:
                result=true;
                break;
            case INT32:
                elm.value.int32=x;
                result=true;
                break;
            case UINT32:
                elm.value.uint32=x;
                result=true;
                break;
            case INT64:
                elm.value.int64=x;
                result=true;
                break;
            case UINT64:
                static if (is(BaseT:ulong)) {
                    elm.value.uint64=cast(ulong)x;
                    result=true;
                }
                break;
            case NATIVE_HBSON_ARRAY:
                static if ( is(BaseT:const(HBSON[])) ) {
                    elm.value.hbson_array=x;
                    result=true;
                }
                break;
            case NATIVE_ARRAY:
                static if ( is(BaseT:const(Document[])) ) {
                    elm.value.document_array=x;
                    result=true;
                }
                break;
            case NATIVE_STRING_ARRAY:
                static if ( is(BaseT==string[]) ) {
                    elm.value.text_array=x;
                    result=true;
                }
                break;
            case NATIVE_DOCUMENT:
                static if ( is(BaseT:const(Document)) ) {
                    elm.value.binary=x.data;
                    result=true;
                }
                break;
            }
            assert(result, format("Unmatch type %s(%s) @ %s. Expected  HBSON type '%s'",
                    T.stringof, TypeString!T, key, typeString));
        }
    }
    */

    void opIndexAssign(T, Index)(T x, const Index index) if (isIntegral!Index) {
        opIndexAssign(x, index.to!string);
    }

    void opIndexAssign(T)(T x, string key) {
        alias BaseT=TypedefType!T;
        alias UnqualT=Unqual!BaseT;
        static if (is(UnqualT == bool)) {
            insert(Type.BOOLEAN, key, x);
        }
        else static if (is(UnqualT == int)) {
            insert(Type.INT32, key, x);
        }
        else static if (is(UnqualT == long)) {
            insert(Type.INT64, key, x);
        }
        else static if (is(UnqualT == double)) {
            insert(Type.DOUBLE, key, x);
        }
        else static if (is(UnqualT == uint)) {
            insert(Type.UINT32, key, x);
        }
        else static if (is(UnqualT == ulong)) {
            insert(Type.UINT64, key, x);
        }
        else static if (is(UnqualT == float)) {
            insert(Type.FLOAT, key, x);
        }
        else static if (is(UnqualT == string)) {
            insert(Type.STRING, key, x);
        }
        else static if (is(UnqualT == Date)) {
            insert(Type.DATE, key, x);
        }
        // else static if (isGeneralType!(BaseT, DateTime)) {
        //     insert(Type.TIMESTAMP, key, x);
        // }
        // else static if (is(BaseT:string[])) {
        //     insert(Type.NATIVE_STRING_ARRAY, key, x);
        // }
        else static if (is(BaseT:const(HBSON))) {
            insert(Type.DOCUMENT, key, x);
        }
        else static if (is(BaseT:const(Document)) ) {
            insert(Type.NATIVE_DOCUMENT, key, x);
        }
        else static if (is(BaseT:const(Document[])) ) {
            insert(Type.NATIVE_ARRAY, key, x);
        }
        else static if (is(BaseT:const(HBSON[])) ) {
            insert(Type.NATIVE_HBSON_ARRAY, key, x);
        }
        else static if (isSubType!BaseT) {
            insert(Type.BINARY, key, x, getSubtype!BaseT);
        }
        else static if (is(BaseT:U[],U)) {
            insert(Type.ARRAY, key, x);
        }
        else static if (is(BaseT==enum) && is(BaseT : const(uint)) ) {
            insert(Type.UINT32, key, cast(uint)x);
        }
        else {
            static assert(0, format("opIndexAssign does not support type %s", T.stringof));
        }
    }

    unittest { // opIndexAssign type test
        auto hbson=new HBSON;
        {
            const bool x=true;
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.BOOLEAN);
        }

        {
            const int x=-42;
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.INT32);
        }

        {
            const long x=-42;
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.INT64);
        }

        {
            const double x=-42.42;
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.DOUBLE);
        }

        {
            const uint x=42;
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.UINT32);
        }

        {
            const ulong x=42;
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.UINT64);
        }

        {
            const float x=-42.42;
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.FLOAT);
        }

        {
            const string x="some_text";
            enum type=typeof(x).stringof;
            hbson[type]=x;
            assert(hbson[type].type == Type.STRING);
        }

    }

    // void setNull(string key) {
    //     append(Type.NULL, key, null);
    // }

    unittest { // bool bug-fix test
        auto hbson=new HBSON;
        const x=true;
        hbson["bool"]=x;
        immutable data=hbson.serialize;

        auto doc=Document(data);
        auto value=doc["bool"];
        assert(value.type == Type.BOOLEAN);
        assert(value.get!bool == true);
    }

    unittest { // Assign Document[]
        HBSON hbson;
        Document[] docs;
        hbson=new HBSON;
        hbson["int_0"]=0;
        docs~=Document(hbson.serialize);
        hbson=new HBSON;
        hbson["int_1"]=1;
        docs~=Document(hbson.serialize);
        hbson=new HBSON;
        hbson["int_2"]=2;
        docs~=Document(hbson.serialize);

        hbson=new HBSON;
        hbson["docs"]=docs;


        auto doc=Document(hbson.serialize);

        auto doc_docs=doc["docs"].get!Document;

        assert(doc_docs.length == 3);
        assert(equal(doc_docs.keys, ["0", "1", "2"]));
        assert(equal(doc_docs.indices, [0, 1, 2]));
        foreach(uint i;0..3) {
            assert(doc_docs.hasElement(i.to!string));
            assert(doc_docs.hasElement(i));
            auto e=(i.to!string in doc_docs);
            auto d=doc_docs[i].get!Document;
            assert(d["int_"~i.to!string].get!int == i);
        }
    }

    inout(HBSON) opIndex(const(char)[] key) inout {

        auto iter=Iterator!(const(HBSON), false)(this);
        foreach(b;iter) {
            if ( b.key == key ) {
                return b;
                break;
            }
        }
        throw new HBSONException("Member '"~key.idup~"' not defined");
        assert(0);
    }

    HBSON opIndex(string key) {
        immutable search={key : key};
        auto range=_members.lowerBound(search);
        check(!range.empty, format("Member '%s' not defined", key));
        return range.front;
    }

    bool hasElement(string key) const {
        immutable search={key : key};
        return !(_members.lowerBound(search).empty);
    }

    Type type() pure const nothrow {
        return _type;
    }

    string typeString() pure const  {
        if ( _type is Type.BINARY ) {
            return subtype.to!string;
        }
        else {
            return _type.to!string;
        }
    }

    @trusted
    immutable(char)[] toInfo() const {
        immutable(char)[] result;
        with(Type) final switch(_type) {
            case MIN:
            case MAX:
            case TRUNC:
            case NONE:
            case UNDEFINED:
            case NULL:
                result=to!string(_type);
                break;
            case DOUBLE:
                result~=format("%s %s", to!string(_type), value.number);
                break;
            case FLOAT:
                result~=format("%s %s", to!string(_type), value.number32);
                break;
            case STRING:
            case REGEX:
            case JS_CODE:
            case SYMBOL:
                result~=format("**%s %s", to!string(_type), value.text);
                break;
            case JS_CODE_W_SCOPE:
                result~=format("%s %s :%X", to!string(_type), value.codescope.code, value.codescope.document.id);
                break;
            case DOCUMENT:
            case ARRAY:
                result~=format("##%s :%X", to!string(_type), this.id);
                break;
            case BINARY:
                result~=format("%s.%s", to!string(_type), to!string(subtype));
                // Todo
                break;
            case OID:
                result~=format("%s :%X ", to!string(_type), value.oid.id);
                break;
            case BOOLEAN:
                result~=format("%s %s", to!string(_type), value.boolean);
                break;
            case DATE:
                result~=format("%s %s", to!string(_type), value.date);
                break;
            case DBPOINTER:
                result=to!string(_type);
                break;
            case INT32:
                result~=format("%s %s", to!string(_type), value.int32);
                break;
            case UINT32:
                result~=format("%s %s", to!string(_type), value.uint32);
                break;
            case INT64:
                result~=format("%s %s", to!string(_type), value.int64);
                break;
            case UINT64:
                result~=format("%s %s", to!string(_type), value.uint64);
                break;
            case TIMESTAMP:
                result~=format("%s %s", to!string(_type), value.int64);
                break;
            case HASHDOC:
                assert(0, "Hashdoc not implemented yet");
                break;

            case NATIVE_DOCUMENT:
                result~=format("%s %s", to!string(_type), value.document_array.length);
                break;
            case NATIVE_ARRAY:
                result~=format("%s %s", to!string(_type), value.binary.length);
                break;
            case NATIVE_HBSON_ARRAY:
                result~=format("%s %s", to!string(_type), value.hbson_array.length);
                break;
            case NATIVE_STRING_ARRAY:
                result~=format("%s %s", to!string(_type), value.text_array.length);
            }
        return result;
    }

    string_t toText(string_t=string)() {
        string_t object_toText(HBSON obj) {
            string_t buf;
            bool any=false;
            immutable bool array=(obj.type == Type.ARRAY);
            buf = (array)?"[":"{";
            foreach(k, b; obj) {
                if(any)
                    buf ~= ",\n";
                any = true;
                if (!array) {
                    buf ~= to!string_t(k);
                    buf ~= " : ";
                }
                if ( b.isDocument ) {
                    if ( b.const_pointer ) {
                        buf~=object_toText(*(b.value.document));
                    }
                    else {
                        buf~=object_toText(b.value.document);
                    }
                }
                else {
                    buf~=b.toText!string_t;
                }
            }
            buf ~= (array)?"]":"}";
            return buf;
        }
        string_t binary_toText() {
            string_t buf;
            void loop(T)(T array) {
                bool any=false;
                foreach(n; array) {
                    if (any) {
                        buf ~=", ";
                    }
                    any=true;
                    buf~=to!string_t(n);
                }
            }

            buf="[";
            with (BinarySubType) switch (subtype) {
                case INT32_array:
                    loop(value.int32_array);
                    break;
                case UINT32_array:
                    loop(value.uint32_array);
                    break;
                case INT64_array:
                    loop(value.int64_array);
                    break;
                case UINT64_array:
                    loop(value.uint64_array);
                    break;
                case FLOAT_array:
                    loop(value.float_array);
                    break;
                case DOUBLE_array:
                    loop(value.double_array);
                    break;
                default:
                    loop(value.binary);

                }
            buf~="]";
            return buf;
        }

        with(Type) final switch(_type) {
            case MIN:
            case MAX:
            case NONE:
                return '"'~to!string_t(to!string(_type))~'"';
            // case UNDEFINED:
            //     return "undefined";
            case NULL:
                return "null";
            case DOUBLE:
                return to!string_t(value.number);
            case FLOAT:
                return to!string_t(value.number32);
            case STRING:
            // case REGEX:
            // case JS_CODE:
            // case SYMBOL:
                return to!string_t('"'~value.text~'"') ;
            // case JS_CODE_W_SCOPE:
            //     return to!string_t("["~value.codescope.code~", "~to!string(value.codescope.document.id)~"]");
            case DOCUMENT:
            case ARRAY:
                return object_toText(this);
            case BINARY:
                return binary_toText();
            // case OID:
            //     return to!string_t(toHex(value.oid.id));
            case BOOLEAN:
                return to!string_t(value.boolean);
            case DATE:
                return to!string_t('"'~value.date.toString~'"');
            // case DBPOINTER:
            //     return to!string_t('"'~to!string(_type)~'"');
            case INT32:
                return to!string_t(value.int32);
            case UINT32:
                return to!string_t(value.uint32);
            case INT64:
                return '"'~to!string_t(value.int64)~'"';
            case UINT64:
                return '"'~to!string_t(value.uint64)~'"';
            // case TIMESTAMP:
            //     return '"'~to!string_t(value.int64)~'"';
            }
        assert(0, "Unmatch type");
    }

    static void native_append(T)(T x, ref immutable(ubyte)[] data) {
        static if (is(T:const(bool))) {
            data~=(x)?one:zero;
        }
        else static if (is(T:const(int)) || is(T:const(long)) || is(T:const(double)) ) {
            data~=nativeToLittleEndian(x);
        }
        else static if (is(T:string)) {
            data~=nativeToLittleEndian(cast(uint)x.length+1);
            data~=x;
            data~=zero;
        }
        else static if (is(T:const(HBSON))) {
            data~=x.serialize;
        }
        else static if (is(T:const(Document))) {
            data~=x.data;
        }
        else {
            static assert(0, "Unsupported type "~T.stringof);
        }

    }

    enum zero = cast(ubyte)0;
    enum one  = cast(ubyte)1;
    protected void append_native_array(T)(const Type t, ref immutable(ubyte)[] data) const {
        scope immutable(ubyte)[] local;
        foreach(i,a;get!T) {
            local~=t;
            local~=i.to!string;
            local~=zero;
            native_append(a, local);
        }
        data~=nativeToLittleEndian(cast(uint)(local.length+uint.sizeof+zero.sizeof));
        data~=local;
        data~=zero;
    }


    immutable(ubyte)[] serialize() const {
        immutable(ubyte)[] local_serialize() {
            immutable(ubyte)[] data;
            foreach(e; iterator!key_sort_flag) {
                data~=(e._type & Type.TRUNC);
                data~=e.key;
                data~=zero;
                with(Type) final switch(e._type) {
                    case NONE:
                        data~=zero;
                        break;
                    case DOUBLE:
                        data~=nativeToLittleEndian(e.value.number);
                        break;
                    case FLOAT:
                        data~=nativeToLittleEndian(e.value.number32);
                        break;
                    case STRING:
                    case SYMBOL:
                    case JS_CODE:
                        data~=nativeToLittleEndian(cast(uint)e.value.text.length+1);
                        data~=e.value.text;
                        data~=zero;
                        //dgelm(data);
                        break;
                    case DOCUMENT:
                    case ARRAY:
                        data~=e.value.document.serialize;
                        break;
                    case NATIVE_HBSON_ARRAY:
                        e.append_native_array!(HBSON[])(DOCUMENT, data);
                        break;
                    case NATIVE_ARRAY:
                        e.append_native_array!(Document[])(DOCUMENT, data);
                        break;
                    case NATIVE_STRING_ARRAY:
                        e.append_native_array!(string[])(STRING, data);
                        break;
                    case BINARY:
                        e.append_binary(data);
                        break;
                    case HASHDOC:
                        assert(0, "Hashdoc not implemented yet");
                        break;
                    case UNDEFINED:
                    case NULL:
                    case MAX:
                    case MIN:
                    case TRUNC:
                        break;
                    case OID:
                        data~=e.value.oid.id;
                        break;
                    case BOOLEAN:
                        data~=(e.value.boolean)?one:zero;
                        break;
                    case DATE:
                        break;
                    case REGEX:
                        data~=e.value.regex[0];
                        data~=zero;
                        data~=e.value.regex[1];
                        data~=zero;
                        break;
                    case DBPOINTER:
                        assert(0, format("%s not supported", DBPOINTER));
                        break;

                    case JS_CODE_W_SCOPE:
                        immutable(ubyte)[] local=e.serialize();
                        // Size of block
                        data~=nativeToLittleEndian(cast(uint)(local.length+uint.sizeof+e.value.text.length+1));
                        data~=nativeToLittleEndian(cast(uint)(e.value.text.length+1));
                        data~=e.value.text;
                        data~=zero;
                        data~=local;
                        break;
                    case INT32:
                        data~=nativeToLittleEndian(e.value.int32);
                        //dgelm(data);
                        break;
                    case UINT32:
                        data~=nativeToLittleEndian(e.value.uint32);
                        //dgelm(data);
                        break;
                    case TIMESTAMP:
                    case INT64:
                        data~=nativeToLittleEndian(e.value.int64);
                        //dgelm(data);
                        break;
                    case UINT64:
                        data~=nativeToLittleEndian(e.value.uint64);
                        //dgelm(data);
                        break;
                    case NATIVE_DOCUMENT:
                        data~=e.value.binary;
                        break;
                    }
            }
            return data;
        }
        immutable(ubyte)[] data;
        scope immutable(ubyte)[] local=local_serialize();
        data~=nativeToLittleEndian(cast(uint)(local.length+uint.sizeof+zero.sizeof));
        data~=local;
        data~=zero;
        return data;
    }

//    version(none)
    unittest {
        HBSON hbson1=new HBSON;


        hbson1["int"]=3;
        hbson1["number"]=1.7;
        hbson1["bool"]=true;
        hbson1["text"]="sometext";

        assert(!hbson1.duble);
        {
            auto iter=hbson1.iterator;
//            iter.popFront;
            assert(!iter.empty);
            assert(iter.front.key == "text");
            iter.popFront;
            assert(!iter.empty);
            assert(iter.front.key == "bool");
            iter.popFront;
            assert(iter.front.key == "number");
            iter.popFront;
            assert(iter.front.key == "int");
            iter.popFront;
            assert(iter.empty);
        }

        immutable(ubyte)[] data1;
        data1=hbson1.serialize();

        {
            auto doc=Document(data1);
            assert(doc.hasElement("int"));
            assert(doc.hasElement("bool"));
            assert(doc.hasElement("number"));
            assert(doc.hasElement("text"));
            assert(doc.length == 4);
            assert(doc["int"].get!int == 3);
            assert(doc["bool"].get!bool);
            assert(doc["number"].get!double == 1.7);
            assert(doc["text"].get!string == "sometext");

        }

        HBSON hbson2=new HBSON;
        hbson2["x"] = 10;
        hbson1["obj"]=hbson2;

        data1=hbson1.serialize();
        {
            auto doc1b=Document(data1);
            assert(doc1b.hasElement("obj"));
            assert(doc1b["obj"].isDocument);
            auto subobj=doc1b["obj"].get!Document;

            assert(subobj.hasElement("x"));
            assert(subobj["x"].isNumber);
            assert(subobj["x"].get!int == 10);
        }
    }

    unittest { // Test of serializing of a cost(HBSON)
        auto stream(const(HBSON) b) {
            return b.serialize;
        }
        {
            auto hbson = new HBSON;
            hbson["x"] = 10;
            hbson["s"] = "text";
            auto data_const=stream(hbson);
            assert(data_const == hbson.serialize);
        }
        { // const(HBSON) member
            auto hbson1=new HBSON;
            auto hbson2=new HBSON;
            auto sub_hbson=new HBSON;
            sub_hbson["x"]=10;
            hbson1["num"]=42;
            hbson2["num"]=42;
            hbson1["obj"]=cast(HBSON)sub_hbson;
            hbson2["obj"]=sub_hbson;
            assert(hbson1.serialize == hbson2.serialize);
            assert(stream(hbson1) == hbson2.serialize);
            assert(hbson1.serialize == stream(hbson2));
        }
    }

    unittest {
        // Test D array types
        HBSON hbson;
        { // Boolean array
            immutable bools=[true, false, true];
            hbson=new HBSON;
            hbson["bools"]=bools;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("bools"));
            auto subarray=doc["bools"].get!(typeof(bools));

            assert(subarray[0] == bools[0]);
            assert(subarray[1] == bools[1]);
            assert(subarray[2] == bools[2]);
        }

        { // Int array
            immutable(int[]) int32s=[7, -9, 13];
            hbson=new HBSON;
            hbson["int32s"]=int32s;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("int32s"));
            auto subarray=doc["int32s"].get!(typeof(int32s));

            assert(subarray[0] == int32s[0]);
            assert(subarray[1] == int32s[1]);
            assert(subarray[2] == int32s[2]);
        }

        { // Unsigned int array
            immutable(uint[]) uint32s=[7, 9, 13];
            hbson=new HBSON;
            hbson["uint32s"]=uint32s;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("uint32s"));
            auto subarray=doc["uint32s"].get!(typeof(uint32s));

            assert(subarray[0] == uint32s[0]);
            assert(subarray[1] == uint32s[1]);
            assert(subarray[2] == uint32s[2]);
        }

        { // Long array
            immutable(long[]) int64s=[7, 9, -13];
            hbson=new HBSON;
            hbson["int64s"]=int64s;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("int64s"));
            auto subarray=doc["int64s"].get!(typeof(int64s));

            assert(subarray[0] == int64s[0]);
            assert(subarray[1] == int64s[1]);
            assert(subarray[2] == int64s[2]);
        }

        { // Unsigned long array
            immutable(ulong[]) uint64s=[7, 9, 13];
            hbson=new HBSON;
            hbson["uint64s"]=uint64s;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("uint64s"));
            auto subarray=doc["uint64s"].get!(typeof(uint64s));

            assert(subarray[0] == uint64s[0]);
            assert(subarray[1] == uint64s[1]);
            assert(subarray[2] == uint64s[2]);
        }

        { // double array
            immutable(double[]) doubles=[7.7, 9.9, 13.13];
            hbson=new HBSON;
            hbson["doubles"]=doubles;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("doubles"));
            auto subarray=doc["doubles"].get!(typeof(doubles));

            assert(subarray[0] == doubles[0]);
            assert(subarray[1] == doubles[1]);
            assert(subarray[2] == doubles[2]);
        }


        { // float array
            immutable(float[]) floats=[7.7, 9.9, 13.13];
            hbson=new HBSON;
            hbson["floats"]=floats;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("floats"));
            auto subarray=doc["floats"].get!(typeof(floats));

            assert(subarray[0] == floats[0]);
            assert(subarray[1] == floats[1]);
            assert(subarray[2] == floats[2]);
        }

        { // string array
            string[] strings=["Hej", "med", "dig"];
            hbson=new HBSON;
            hbson["strings"]=strings;

            auto doc=Document(hbson.serialize);
            assert(doc.hasElement("strings"));
            auto subarray=doc["strings"].get!Document;

            assert(subarray[0].get!string == strings[0]);
            assert(subarray[1].get!string == strings[1]);
            assert(subarray[2].get!string == strings[2]);
        }

        {
            HBSON[] hbsons;
            hbson=new HBSON;
            hbson["x"]=10;
            hbsons~=hbson;
            hbson=new HBSON;
            hbson["y"]="kurt";
            hbsons~=hbson;
            hbson=new HBSON;
            hbson["z"]=true;
            hbsons~=hbson;
            hbson=new HBSON;

            hbson["hbsons"]=hbsons;

            auto data=hbson.serialize;

            auto doc=Document(hbson.serialize);

            assert(doc.hasElement("hbsons"));

            auto subarray=doc["hbsons"].get!Document;
            assert(subarray[0].get!Document["x"].get!int == 10);
            assert(subarray[1].get!Document["y"].get!string == "kurt");
            assert(subarray[2].get!Document["z"].get!bool == true);
        }
    }

    unittest  {
        // Buffer as binary arrays
        HBSON hbson;
        {

            hbson=new HBSON;
//            hbson.typedarray=true;
            { // Typedarray int32
                immutable(int[]) int32s= [ -7, 9, -13];
                hbson["int32s"]=int32s;
                auto doc = Document(hbson.serialize);


                assert(doc.hasElement("int32s"));
                auto element=doc["int32s"];
                assert(element.get!(immutable(int)[]).length == int32s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])int32s);
                assert(element.get!(immutable(int)[]) == int32s);
            }

            { // Typedarray uint32
                immutable(uint[]) uint32s= [ 7, 9, 13];
                hbson["uint32s"]=uint32s;
                auto doc = Document(hbson.serialize);

                assert(doc.hasElement("uint32s"));
                auto element=doc["uint32s"];
                assert(element.get!(immutable(uint)[]).length == uint32s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])uint32s);
                assert(element.get!(immutable(uint)[]) == uint32s);
            }

            { // Typedarray int64
                immutable(long[]) int64s= [ -7_000_000_000_000, 9_000_000_000_000, -13_000_000_000_000];
                hbson["int64s"]=int64s;
                auto doc = Document(hbson.serialize);

                assert(doc.hasElement("int64s"));
                auto element=doc["int64s"];
                assert(element.get!(immutable(long)[]).length == int64s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])int64s);
                assert(element.get!(immutable(long)[]) == int64s);
            }


            { // Typedarray uint64
                immutable(long[]) uint64s= [ -7_000_000_000_000, 9_000_000_000_000, -13_000_000_000_000];
                hbson["uint64s"]=uint64s;
                auto doc = Document(hbson.serialize);

                assert(doc.hasElement("uint64s"));
                auto element=doc["uint64s"];
                assert(element.get!(immutable(long)[]).length == uint64s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])uint64s);
                assert(element.get!(immutable(long)[]) == uint64s);
            }

            { // Typedarray number64
                immutable(double[]) number64s= [ -7.7e9, 9.9e-4, -13e200];
                hbson["number64s"]=number64s;
                auto doc = Document(hbson.serialize);

                assert(doc.hasElement("number64s"));
                auto element=doc["number64s"];
                assert(element.get!(immutable(double)[]).length == number64s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])number64s);
                assert(element.get!(immutable(double)[]) == number64s);
            }


            { // Typedarray number32
                immutable(float[]) number32s= [ -7.7e9, 9.9e-4, -13e20];
                hbson["number32s"]=number32s;
                auto doc = Document(hbson.serialize);

                assert(doc.hasElement("number32s"));
                auto element=doc["number32s"];
                assert(element.get!(immutable(float)[]).length == number32s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])number32s);
                assert(element.get!(immutable(float)[]) == number32s);
            }

//            immutable(int[]) uint32s= [ 7, 9, -13];

//            assert(0);
        }
    }

    bool duble() {
        auto iter=iterator;
        for(; !iter.empty; iter.popFront) {
            auto dup_iter=iter;
            for(dup_iter.popFront; !dup_iter.empty; dup_iter.popFront) {
                if (dup_iter.front.key == iter.front.key) {
                    return true;
                }
            }
        }
        return false;
    }


    bool remove(string key) {
        auto iter=iterator;
        bool result;
        HBSON prev;
        for(; !iter.empty; iter.popFront) {
            if ( iter.front.key == key ) {
                // If the key is found then remove it from the change
                if ( members is iter.front ) {
                    // Remove the root member
                    members=members.members;
                }
                else {
                    prev.members=iter.front.members;
                }
                result = true;
            }
            prev=iter.front;
        }
        return result;
    }

    unittest {
        static if (!one_time_write) {
            // Remove and duble check
            HBSON hbson;
            hbson=new HBSON;
            hbson["a"]=3;
            hbson["b"]=13;

            assert(hbson["a"].get!int == 3);
            hbson["a"] = 4;

            uint i;
            foreach(b; hbson) {
                if ( b.key == "a" ) {
                    i++;
                }
            }
            assert(i == 2);
            assert(hbson.duble);

            hbson=new HBSON;
            hbson.no_duble=true;

            hbson["a"] = 3;
            hbson["b"] = 13;
            hbson["a"] = 4;

            assert(!hbson.duble);

            assert(hbson["a"].get!int==4);
        }
    }

    Iterator!(HBSON, F) iterator(bool F=false)() {
        return Iterator!(HBSON, F)(this);
    }

    Iterator!(const(HBSON), F) iterator(bool F=false)() const {
        return Iterator!(const(HBSON), F)(this);
    }


    @trusted
    protected immutable(ubyte)[] subtype_buffer() const {
        with(BinarySubType) final switch(subtype) {
            case GENERIC:
                return value.binary;

            // case FUNC:
            // case BINARY:
            // case UUID:
            // case MD5:
            case userDefined:
                check(0, format("The subtype %s should not be used as a type", subtype));
//                return value.binary;
            case INT32_array:
                return (cast(immutable(ubyte)*)(value.int32_array.ptr))[0..value.int32_array.length*int.sizeof];
            case UINT32_array:
                return (cast(immutable(ubyte)*)(value.uint32_array.ptr))[0..value.uint32_array.length*uint.sizeof];
            case INT64_array:
                return (cast(immutable(ubyte)*)(value.int64_array.ptr))[0..value.int64_array.length*long.sizeof];
            case UINT64_array:
                return (cast(immutable(ubyte)*)(value.uint64_array.ptr))[0..value.uint64_array.length*ulong.sizeof];
            case DOUBLE_array:
                return (cast(immutable(ubyte)*)(value.double_array.ptr))[0..value.double_array.length*double.sizeof];
            case FLOAT_array:
                return (cast(immutable(ubyte)*)(value.float_array.ptr))[0..value.float_array.length*float.sizeof];
            case DECIMAL_array:
                return (cast(immutable(decimal)*)(value.float_array.ptr))[0..value.float_array.length*decimal.sizeof];
            case BOOLEAN_array:
                return (cast(immutable(ubyte)*)(value.bool_array.ptr))[0..value.bool_array.length*bool.sizeof];
            // case BIGINT, not_defined:
            //     throw new HBSONException("Binary suptype "~to!string(subtype)~" not supported for buffer");

            }

    }

    protected void append_binary(ref immutable(ubyte)[] data) const {
        scope binary=subtype_buffer;
        data~=nativeToLittleEndian(cast(uint)(binary.length));
        data~=cast(ubyte)subtype;
        data~=binary;
    }


    Members.ConstRange keys() pure const nothrow {
        return KeyIterator(this);
    }

    size_t length() const {
        return _members.length;
    }

    unittest {
        // Test keys function
        // and the sorted HBSON
        {
            auto hbson=new HBSON!true;
            auto some_keys=["kurt", "abe", "ole"];
            hbson[some_keys[0]]=0;
            hbson[some_keys[1]]=1;
            hbson[some_keys[2]]=2;
            auto keys=hbson.keys;
            // writefln("keys=%s", keys);
            auto data=hbson.serialize;
            auto doc=Document(data);
            // writefln("doc.keys=%s", doc.keys);
            // Check that doc.keys are sorted
            assert(equal(doc.keys, ["abe", "kurt", "ole"]));
        }
        {
            import std.array : to_array=array;
            HBSON!true[] array;
            for(int i=10; i>-7; i--) {
                auto len=new HBSON!true;
                len["i"]=i;
                array~=len;
            }
            auto hbson=new HBSON!true;
            hbson["array"]=array;
            auto data=hbson.serialize;
            auto doc=Document(data);
            auto doc_array=doc["array"].get!Document;
            foreach(i,k; to_array(doc_array.keys)) {
                assert(to!string(i) == k);
            }
        }

    }

    int opApply(scope int delegate(HBSON hbson) @safe dg) {
        return iterator.opApply(dg);
    }

    int opApply(scope int delegate(in string key, HBSON hbson) @safe dg) {
        return iterator.opApply(dg);
    }

    @safe
    struct KeyIterator {
        protected Members.ConstRange range;
        this(const(HBSON) owner) nothrow {
            range=owner._members[]:
        }
        void popFront() {
            range.popFront;
        }
        string front() pure const {
            return range.front.key;
        }
        bool empty() pure const {
            return range.empty;
        }
    }

    @safe
    struct Iterator(THBSON, bool key_sort_flag) {
        static assert( is (THBSON:const(HBSON)), format("Iterator only supports %s ",HBSON.stringof));
        private THBSON owner;
        enum owner_is_mutable=is(THBSON==HBSON);
        static if (key_sort_flag) {
            private string[] sorted_keys;
            private string[] current_keys;
        }
        else {
//            static assert(is(THBSON==HBSON), format("Non sorted HBSON does not support %s", THBSON.stringof));
            static if ( owner_is_mutable ) {
                private HBSON current;
            }
            else {
                private THBSON* current;
            }
        }
        this(THBSON owner) {
            this.owner=owner;
            static if ( key_sort_flag ) {
                void keylist(const(HBSON) owner) {
                    sorted_keys=owner.keys;
                    sort!(less_than, SwapStrategy.stable)(sorted_keys);
                    current_keys=sorted_keys;
                }
                keylist(owner);
            }
            else static if ( owner_is_mutable ) {
                current=owner.members;
            }
            else {
                current=&(owner.members);
            }
        }
        void popFront()
            in {
                static if ( !key_sort_flag ) {
                    assert(owner !is null);
                    static if ( owner_is_mutable ) {
                        assert(current !is owner,"Circular reference member "~current.key~" points to it self");
                    }
                    else {
                        if ( current ) {
                            assert(*current !is owner,"Circular reference member "~current.key~" points to it self");
                        }
                    }
                }
            }
        do {
            static if ( key_sort_flag ) {
                current_keys=current_keys[1..$];
            }
            else static if ( owner_is_mutable ) {
                current=current.members;
            }
            else {
                auto result() @trusted {
                    if ( current !is null ) {
                        return &(current.members);
                    }
                    else {
                        return null;
                    }
                }
                current=result();
            }
        }

        THBSON front() {
            static if ( key_sort_flag ) {
                assert ( current_keys.length > 0 );
                return owner[current_keys[0]];
            }
            else static if ( owner_is_mutable ) {
                return current;
            }
            else {
                return *current;
            }
        }

        bool empty() {
            static if ( key_sort_flag ) {
                return current_keys.length == 0;
            }
            else static if ( owner_is_mutable ) {
                return current is null;
            }
            else {
                auto result=(current is null) || (*current is null);
                scope(exit) {
                    if ( result ) {
                        current = null;
                    }
                }
                return result;
            }
        }

        final int opApply(scope int delegate(THBSON hbson) @safe dg) {
            int result;
            for(; !empty; popFront) {
                if ( (result=dg(front))!=0 ) {
                    break;
                }
            }
            return result;
        }

        final int opApply(scope int delegate(in string key, THBSON hbson) @safe dg) {
            int result;
            for(; !empty; popFront) {
                if ( (result=dg(front.key, front))!=0 ) {
                    break;
                }
            }
            return result;
        }

    }

}



// int[] doc2ints(Document doc) {
//     int[] result;
//     foreach(elm; doc.opSlice) {
//         result~=elm.as!int;
//     }
//     return result;
// }

// double[] doc2doubles(Document doc) {
//     double[] result;
//     foreach(elm; doc.opSlice) {
//         result~=elm.as!double;
//     }
//     return result;
// }


unittest { // HBSON with const member
    alias GHBSON=HBSON!true;
    auto hbson1=new GHBSON;
    auto hbson2=new GHBSON;
    hbson1["hugh"]="Some data";
    hbson1["age"]=42;
    hbson1["height"]=155.7;

    hbson2["obj"]=hbson1;
    immutable hbson1_data=hbson1.serialize;
    immutable hbson2_data=hbson2.serialize;

    auto doc1=Document(hbson1_data);
    auto doc2=Document(hbson2_data);

    assert(hbson1_data.length == doc1.data.length);
    assert(hbson1_data == doc1.data);

    assert(hbson2_data.length == doc2.data.length);
    assert(hbson2_data == doc2.data);

    void doc_hbson_const(GHBSON hbson, const(GHBSON) b) {

        hbson["obj"]=b;
    }

    auto hbson2c=new GHBSON;
    doc_hbson_const(hbson2c, hbson1);

    immutable hbson2c_data=hbson2c.serialize;
    auto doc2c=Document(hbson2c_data);
    assert(hbson2c_data == doc2c.data);
    assert(doc2c.data == doc2.data);

}

unittest { // Test of Native Document type
    // The native document type is only used as an internal representation of the Document
    auto hbson1=new HBSON;
    auto hbson2=new HBSON;
    auto doc_hbson=new HBSON;
    doc_hbson["int"]=10;
    doc_hbson["bool"]=true;
    hbson1["obj"]=doc_hbson;

    // Test of using native Documnet as a object member
    auto doc=Document(doc_hbson.serialize);
    hbson2["obj"]=doc;
    auto data1=hbson1.serialize;
    // writefln("%s:%d", data1, data1.length);
    auto data2=hbson2.serialize;
    // writefln("%s:%d", data2, data2.length);
    assert(data1.length == data2.length);
    assert(data1 == data2);
}
