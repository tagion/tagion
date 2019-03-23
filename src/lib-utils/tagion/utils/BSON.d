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
module tagion.utils.BSON;

import core.stdc.string;  // Some operations in Phobos not safe, pure and nothrow, e.g. cmp

import std.algorithm;
import std.conv;
import std.exception;  // assumeUnique
import std.datetime;   // Date, DateTime
import std.typecons;   // Tuple
import std.format;
import std.traits : isSomeString, isIntegral;
private import std.bitmanip;

import tagion.crypto.Hash : toHexString;

public alias HBSON=BSON!(true,true);

static assert(uint.sizeof == 4);


enum Type : byte {
    MIN             = -1,        /// Special type which compares lower than all other possible BSON element values
        NONE            = 0x00,  /// End Of Document
        DOUBLE          = 0x01,  /// Floating point
        STRING          = 0x02,  /// UTF8 STRING
        DOCUMENT        = 0x03,  /// Embedded document
        ARRAY           = 0x04,  ///
        BINARY          = 0x05,  /// Binary data
        UNDEFINED       = 0x06,  /// UNDEFINED - Deprecated
        OID             = 0x07,  /// ObjectID
        BOOLEAN         = 0x08,  /// Boolean - true or false
        DATE            = 0x09,  /// UTC datetime
        NULL            = 0x0a,  /// Null value
        REGEX           = 0x0b,  /// Regular expression
        DBPOINTER       = 0x0c,  /// DBPointer - Deprecated
        JS_CODE         = 0x0d,  /// JavaScript Code
        SYMBOL          = 0x0e,  ///
        JS_CODE_W_SCOPE = 0x0f,  /// JavaScript code w/ scope
        INT32           = 0x10,  /// 32-bit integer
        TIMESTAMP       = 0x11,  ///
        INT64           = 0x12,  /// 64-bit integer,

        UINT32          = 0x20,  // 32 bit unsigend integer
        UINT64          = 0x22,  // 64 bit unsigned integer
        FLOAT           = 0x31,  // Float 32
        TRUNC           = 0x3f,  // Trunc value for the native type
        MAX             = 0x7f,  /// Special type which compares higher than all other possible BSON element values
        /// Native types is only used inside the BSON object
        NATIVE_DOCUMENT       = cast(byte)(0x80 | 0x40 | DOCUMENT ),
        NATIVE_BSON_ARRAY     = cast(byte)(0x80 | 0x40 | ARRAY ), // This type is not a valid BSON type it is used to handle the native Document object
        NATIVE_ARRAY          = cast(byte)(0x80 | ARRAY ),
        NATIVE_STRING_ARRAY   = cast(byte)(0x40 | ARRAY )
        }


enum BinarySubType : ubyte {
    GENERIC     = 0x00,  /// Binary / GENERIC
        FUNC        = 0x01,  ///
        BINARY      = 0x02,  /// Binary (Old)
        UUID        = 0x03,  ///
        MD5         = 0x05,  ///
        BIGINT      = 0x06,  /// This is not a valid BSON type only used in HBSON
        userDefined = 0x80,   ///
        /// Non statdard types
        INT32_array     = userDefined | Type.INT32,
        INT64_array     = userDefined | Type.INT64,
        DOUBLE_array    = userDefined | Type.DOUBLE,
        BOOLEAN_array   = userDefined | Type.BOOLEAN,
        UINT32_array    = userDefined | Type.UINT32,
        UINT64_array    = userDefined | Type.UINT64,
        FLOAT_array     = userDefined | Type.FLOAT,
        not_defined     = 0xFF   /// Not defined
        }


private {
    alias BSON_FF=BSON!(false, false);
    alias BSON_TF=BSON!(true, false);
    alias BSON_FT=BSON!(false, true);
    alias BSON_TT=BSON!(true, true);
}

template isGeneralType(T, Type) {
    alias BaseT=TypedefType!T;
    enum isGeneralType=(is(BaseT == inout(Type)) || is(BaseT == Type) || is(BaseT == const(Type)) || is(BaseT == immutable(Type)));
}

enum isTypedef(T)=!is(TypedefType!T == T);

template TypeName(T) {
    static if (isGeneralType!(T,double)) {
        alias TypeName=Type.DOUBLE;
    }
    else static if (isGeneralType!(T,string)) {
        alias TypeName=Type.STRING;
    }
    else static if (is(T==Document)) {
        alias TypeName=Type.DOCUMENT;
    }
    else static if (isGeneralType!(T,bool)) {
        alias TypeName=Type.BOOLEAN;
    }
    else static if (isGeneralType!(T,int)) {
        alias TypeName=Type.INT32;
    }
    else static if (isGeneralType!(T,long)) {
        alias TypeName=Type.INT64;
    }
    else static if (isGeneralType!(T,uint)) {
        alias TypeName=Type.UINT32;
    }
    else static if (isGeneralType!(T,ulong)) {
        alias TypeName=Type.UINT64;
    }
    else static if (isGeneralType!(T,float)) {
        alias TypeName=Type.FLOAT;
    }
    else static if (is(T:immutable(U[]), U)) {
        static if (is(T:immutable(ubyte[]))) {
            alias TypeName=BinarySubType.GENERIC;
        }
        else static if (is(T:immutable(int[]))) {
            alias TypeName=BinarySubType.INT32_array;
        }
        else static if (is(T:immutable(uint[]))) {
            alias TypeName=BinarySubType.UINT32_array;
        }
        else static if (is(T:immutable(long[]))) {
            alias TypeName=BinarySubType.INT64_array;
        }
        else static if (is(T:immutable(ulong[]))) {
            alias TypeName=BinarySubType.UINT64_array;
        }
        else static if (is(T:immutable(float[]))) {
            alias TypeName=BinarySubType.FLOAT_array;
        }
        else static if (is(T:immutable(double[]))) {
            alias TypeName=BinarySubType.INT64_array;
        }
        else static if (is(T:immutable(long[]))) {
            alias TypeName=BinarySubType.INT64_array;
        }
        else static if (is(T:immutable(bool[]))) {
            alias TypeName=BinarySubType.BOOL_array;
        }
    }
    else {
        static assert(0, format("Type %s does not have a BSON equivalent type", T.stringof));
    }
}

@safe
interface DocumentCallbacks {
    //bool check(bool flag, string msg, uint code=0);
    void not_found(lazy string msg, string file = __FILE__, size_t line = __LINE__ );
}

bool less_than(string a, string b) @safe  {
    bool toUint(string str, out ulong value) @safe {
        foreach(s;str) {
            if ( (value == 0) && ( s == '0' ) ) {
                return true;
            }
            if ( (s >= '0') && ( s <= '9' ) ) {
                value*=10;
                value+=(s-'0');
                if ( value > uint.max ) {
                    return false;
                }
            }
            else {
                return false;
            }
        }
        return true;
    }
    ulong a_value, b_value;
    immutable a_is_uint=toUint(a, a_value);
    immutable b_is_uint=toUint(b, b_value);
    if ( a_is_uint ) {
        if ( b_is_uint ) {
            return (a_value < b_value);
        }
        return true;
    }
    else if ( b_is_uint ) {
        return false;
    }
    else {
        return a < b;
    }
}

unittest {
    assert(less_than("abe", "bob"));
    assert(less_than("0", "abe"));
    assert(less_than("0", "1"));
    assert(!less_than("00", "0"));
}




@safe
struct Document {
    immutable(ubyte[]) data;

    static DocumentCallbacks callbacks;

    nothrow this(immutable ubyte[] data) {
        this.data = data;
    }

    Document idup() const nothrow {
        return Document(data.idup);
    }

    @property nothrow pure const {
        @safe bool empty() {
            return data.length < 5;
        }


        @trusted uint size() {
            return *cast(uint*)(data[0..uint.sizeof].ptr);
        }
    }

    @trusted
    @property uint length() const {
        uint counter;
        foreach(i; Range(data)) {
            counter++;
        }
        return counter;
    }

    // FIXME: Check for index out of range and call the error function
    // This function will throw an RangeError if length format is wrong
    bool isInOrder(bool function(const(Element) elm, ref bool result) @safe error=null)  {
        bool local_order(const(Element) previous, Range range) @safe {
            //writefln("previous.key=%s", previous.key);
            range.popFront;
            bool result=true;
            if ( !range.empty ) {
                //writefln("\tprevious.key=%s range.front.key=%s", previous.key, range.front.key);
                result=less_than(previous.key, range.front.key);
                if ( result && range.front.isDocument ) {
                    auto sub_range=Range(range.front.value);
                    result=local_order(sub_range.front, sub_range);
                }
                if ( result ) {
                    result=local_order(range.front, range);
                }
                if ( error ) {
                    result=error(range.front, result);
                }
            }

            return result;
        }
        auto local_range=Range(data);
        return local_order(local_range.front, local_range);
    }


    string toText(string INDENT="  ", string EOL="\n")() {
        enum BETWEEN=","~EOL;
        string object_toText(Document doc, const Type type, immutable(string) indent=null) @safe {
            string buf;
            bool any=false;
            immutable bool array=(type == Type.ARRAY);
            buf ~=indent;
            buf =(array)?"[":"{";
            string lines(Range)(Range range, immutable(string) indent, immutable(string) separator=EOL) @safe {
                if ( !range.empty) {
                    const e=range.front;
                    range.popFront;
                    if ( e.isDocument ) {
                        return format("%s%s%s : %s", separator, indent, e.key, object_toText(e.get!Document, e.type, indent))~
                            lines(range, indent, BETWEEN);

                    }
                    else {
                        return format("%s%s%s : (%s)%s", separator, indent, e.key, e.typeName, e.toInfo) ~
                            lines(range, indent, BETWEEN);
                    }
                }
                return "\n";
            }
            buf~=lines(doc[], indent~INDENT);
            buf ~=indent;
            buf ~= (array)?"]":"}";
            return buf;
        }
        return object_toText(this, Type.DOCUMENT);
    }

    unittest { // isInOrder
        void build(B)(B bson) {
            auto obj=new B;
            obj["a"]=7;
            obj["b"]=8;
            bson["banana"]=1;
            bson["orange"]=obj;
            bson["apple"]=3;
        }
        //auto hbson=new HBSON;
        auto bson=new BSON!(false, false);
        build(bson);
        // import std.stdio;
        // writefln("bson is inOrder=%s", Document(bson.serialize).isInOrder);
        assert(!Document(bson.serialize).isInOrder);
        auto hbson=new HBSON;
        build(hbson);
        // writefln("hbson is inOrder=%s", Document(hbson.serialize).isInOrder);
        assert(Document(hbson.serialize).isInOrder);

    }

    struct Range {
        immutable(ubyte[]) data;
    protected:
        size_t            _index;
        Element           _element;


    public:
        @safe
        this(immutable(ubyte[]) data) {
            this.data = data;

            if (data.length == 0) {
                _index = 0;
            }
            else {
                _index = 4;
                popFront();
            }
        }


        @property @safe pure nothrow const {
            bool empty() {
                return _index >= data.length;
            }


            /**
             * InputRange primitive operation that returns the currently iterated element.
             */
            const(Element) front() {
                return _element;
            }
        }


        /**
         * InputRange primitive operation that advances the range to its next element.
         */
        @trusted
        void popFront() {
            import std.conv;

            emplace!Element(&_element, data[_index..$]);
            _index += _element.size;
        }
    }

    Range opSlice() {
        return Range(data);
    }

    @trusted
    string[] keys() const {
        import std.array;
        return array(map!"a.key"(Range(data)));
    }

    // Throws an std.conv.ConvException if the keys can not be convert to an uint
    immutable(uint[]) indices() const {
        import std.array;
        return array(map!"a.key.to!uint"(Range(data))).idup;
    }

    bool hasElement(in string key) const {
        return !opIn_r(key).isEod();
    }


    bool hasElement(Index)(in Index index) const if (isIntegral!Index) {
        return hasElement(index.to!string);
    }

    const(Element) opIn_r(in string key) const {
        foreach (ref element; Range(data)) {
            if (element.key == key) {
                return element;
            }
        }
        return Element();
    }

    const(Element) opIndex(in string key) const {
        auto result=key in this;
        if ((callbacks !is null) && result.isEod) {
            callbacks.not_found(format("Member named '%s' not found", key));
        }
        return result;
    }

    const(Element) opIndex(Index)(in Index index) const if (isIntegral!Index) {
        return opIndex(index.to!string);
    }


    // immutable(ubyte[]) data() const pure nothrow {
    //     return _data;
    // }

    alias serialize=data;

    string toString() const {
        if (empty) {
            return "{}";
        }
        return "";
    }
}


unittest {
    // {foo: "bar", bool: true, num: 10}
    immutable ubyte[] data = [0x22, 0x00, 0x00, 0x00, 0x02, 0x66, 0x6f, 0x6f, 0x00, 0x04, 0x00, 0x00, 0x00, 0x62, 0x61, 0x72, 0x00,
        0x08, 0x62, 0x6f, 0x6f, 0x6c, 0x00, 0x01, 0x10, 0x6e, 0x75, 0x6d, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00];
    auto doc = Document(data);

    { // hasElement
        assert(doc.hasElement("bool"));
        assert(doc.hasElement("foo"));
        assert(doc.hasElement("num"));
        assert(!doc.hasElement("missing"));
    }
    { // opSlice
        auto range = doc[];
        assert(count(range) == 3);
    }
    { // keys
        assert(doc.keys == ["foo", "bool", "num"]);
    }
    { // opIndex([])
        auto strElem = doc["foo"];
        assert(strElem.str == "bar");

        auto numElem = doc["num"];
        assert(numElem.get!int == 10);
        assert(numElem.get!(const(int)) == 10);
        assert(numElem.get!(immutable(int)) == 10);
        // assert(numElem.get!uint == 10);
        // assert(numElem.get!(const(uint)) == 10);
        // assert(numElem.get!(immutable(uint)) == 10);

        auto boolElem = doc["bool"];
        assert(boolElem.get!bool);

        // Typedef check
        alias NewInt=Typedef!int;
        assert(numElem.get!NewInt == 10);

    }
}


/**
 * BSON element representation
 */
@safe
struct Element {
    /*
     * -----
     * //data image:
     * +-----------------------------------+
     * | [type] | [key] | [val | unused... |
     * +-----------------------------------+
     *          ^ type offset(1)
     *                  ^ keySize
     *                         ^ size
     *                                     ^ data.length
     * -----
     */
    immutable(ubyte[]) _data;


public:
    this(immutable(ubyte[]) data) {
        // In this time, Element does not parse a binary data.
        // This is lazy initialization for some efficient.
        _data = data;
    }


    @property @safe const pure nothrow {
        bool isEod() {
            return _data.length == 0;
        }


        bool isNumber() {
            switch (type) {
            case Type.INT32, Type.INT64, Type.DOUBLE, Type.UINT32, Type.UINT64:
                return true;
            default:
                return false;
            }
        }


        bool isSimple() {
            switch (type) {
            case Type.INT32, Type.INT64, Type.DOUBLE, Type.UINT32, Type.UINT64, Type.STRING, Type.BOOLEAN, Type.DATE, Type.OID:
                return true;
            default:
                return false;
            }
        }


        bool isTrue() {
            switch (type) {
            case Type.INT32:
                return _int32() != 0;
            case Type.INT64:
                return _int64() != 0L;
            case Type.UINT32:
                return _uint32() != 0;
            case Type.UINT64:
                return _uint64() != 0L;
            case Type.DOUBLE:
                return _double() != 0.0;
            case Type.BOOLEAN:
                return _boolean();
            case Type.NONE, Type.NULL, Type.UNDEFINED:
                return false;
            default:
                return true;
            }
        }


        bool isDocument() {
            switch (type) {
            case Type.DOCUMENT, Type.ARRAY:
                return true;
            default:
                return false;
            }
        }

        bool isBinary() {
            return type == Type.BINARY;
        }

        BinarySubType subtype() {
            if ( (type == Type.BINARY) && (4<value.length) ) {
                return cast(BinarySubType)value[4];
            }
            else {
                return BinarySubType.not_defined;
            }
            //return ((4<_data.length) )?_data[4]:BinarySubType.non;
        }

        // need mayEncapsulate?
    }

    @property @safe const pure nothrow {
        Type type() {
            if (isEod) {
                return Type.NONE;
            }
            return cast(Type)_data[0];
        }

        byte canonicalType() {
            Type t = type;

            with(Type) final switch (t) {
                case MIN, MAX, TRUNC:
                    return t;
                case NONE, UNDEFINED:
                    return 0;
                case NULL:
                    return 5;
                case DOUBLE, INT32, INT64:
                    return 10;
                case STRING, SYMBOL:
                    return 15;
                case DOCUMENT:
                    return 20;
                case ARRAY:
                    return 25;
                case BINARY:
                    return 30;
                case OID:
                    return 35;
                case BOOLEAN:
                    return 40;
                case DATE, TIMESTAMP:
                    return 45;
                case REGEX:
                    return 50;
                case DBPOINTER:
                    return 55;
                case JS_CODE:
                    return 60;
                case JS_CODE_W_SCOPE:
                    return 65;
                case FLOAT, UINT32, UINT64:
                    return 70;
                case NATIVE_DOCUMENT, NATIVE_ARRAY, NATIVE_BSON_ARRAY, NATIVE_STRING_ARRAY:
                    assert(0, format("Invalid type %s",t));
                }
        }
    }


    @property const pure nothrow {

        string key() @trusted {
            if (isEod) {
                return null;
            }
            immutable k = cast(string)_data[1..$];
            immutable strsize=strlen(k.ptr);
            immutable len=(strsize<k.length)?strsize:k.length;
            return k[0..len];
        }

        size_t keySize() {
            return key.length;
        }

    }

    uint index() const pure {
        return key.to!uint;
    }


    @property @safe const pure nothrow {
        immutable(ubyte[]) value() {
            if (isEod) {
                return null;
            }
            return _data[1 + rawKeySize..size];
        }


        size_t valueSize() {
            return value.length;
        }

    }
    //Binary buffer
    @trusted
    immutable(ubyte[]) binary_buffer() const  {
        auto v=value();
        immutable len=*cast(int*)(v.ptr);
        return v[5..len+5];
    }


    @property @trusted
    size_t size() const pure nothrow {
        size_t s;
        with(Type) final switch (type) {
            case MIN, MAX, TRUNC, NONE, UNDEFINED, NULL:
                break;
            case BOOLEAN:
                s = 1;
                break;
            case INT32, UINT32, FLOAT:
                s = 4;
                break;
            case DOUBLE, INT64, DATE, TIMESTAMP, UINT64:
                s = 8;
                break;
            case OID:
                s = 12;
                break;
            case DOCUMENT, JS_CODE_W_SCOPE, ARRAY:
                s = bodySize;
                break;
            case STRING, SYMBOL, JS_CODE:
                s = bodySize + 4;
                break;
            case BINARY:
                s = bodySize + 4 + 1;
                break;
            case DBPOINTER:
                s = bodySize + 4 + 12;
                break;
            case REGEX:
                auto p1 = cast(immutable(char*))_data[1 + rawKeySize..$].ptr;
                size_t length1 = strlen(p1);
                auto p2 = cast(immutable(char*))_data[1 + rawKeySize + length1 + 1..$].ptr;
                size_t length2 = strlen(p2);
                s = length1 + 1 + length2 + 1;
                break;
            case NATIVE_DOCUMENT:
                s = _data.length;
                break;
            case NATIVE_ARRAY, NATIVE_BSON_ARRAY, NATIVE_STRING_ARRAY:
                assert(0, format("No size defined for type %s", type) );
            }

        return 1 + rawKeySize + s;
    }
    alias size length;

    // D's primitive type accessor like Variant

    @property const /* pure: check is not pure */ {

        string typeName() pure const  {
            if ( type is Type.BINARY ) {
                return subtype.to!string;
            }
            else {
                return type.to!string;
            }
        }

        bool istype(T)() pure const {
            static if (isGeneralType!(T,double)) {
                return type == Type.DOUBLE;
            }
            else static if (isGeneralType!(T,string)) {
                return type == Type.STRING;
            }
            else static if (is(T==Document)) {
                return ((type == Type.DOCUMENT) || (type == Type.ARRAY));
            }
            else static if (isGeneralType!(T,bool)) {
                return (type == Type.BOOLEAN);
            }
            else static if (isGeneralType!(T,int)) {
                return (type == Type.INT32);
            }
            else static if (isGeneralType!(T,long)) {
                return (type == Type.INT64);
            }
            else static if (isGeneralType!(T,uint)) {
                return (type == Type.UINT32);
            }
            else static if (isGeneralType!(T,ulong)) {
                return (type == Type.UINT64);
            }
            else static if (isGeneralType!(T,float)) {
                return (type == Type.FLOAT);
            }
            else static if (is(T:immutable(U[]), U)) {
                static if (is(T:immutable(ubyte[]))) {
                    return (subtype == BinarySubType.GENERIC);
                }
                else static if (is(T:immutable(int[]))) {
                    return (subtype == BinarySubType.INT32_array);
                }
                else static if (is(T:immutable(uint[]))) {
                    return (subtype == BinarySubType.UINT32_array);
                }
                else static if (is(T:immutable(long[]))) {
                    return (subtype == BinarySubType.INT64_array);
                }
                else static if (is(T:immutable(ulong[]))) {
                    return (subtype == BinarySubType.UINT64_array);
                }
                else static if (is(T:immutable(float[]))) {
                    return (subtype == BinarySubType.FLOAT_array);
                }
                else static if (is(T:immutable(double[]))) {
                    return (subtype == BinarySubType.INT64_array);
                }
                else static if (is(T:immutable(bool[]))) {
                    return (subtype == BinarySubType.BOOL_array);
                }
            }
            return false;
        }

        T get(T)() inout if (is(TypedefType!T : const(string))) {
            check(Type.STRING);
            return cast(T)str;
        }

        T get(T)() inout if ( isGeneralType!(T,bool) ) {
            check(Type.BOOLEAN);
            return cast(T)(_boolean());
        }

        T get(T)() inout if (isGeneralType!(T,int) ) {
            check(Type.INT32);
            return cast(T)(_int32());
        }

        T get(T)() inout if (isGeneralType!(T,long) ) {
            check(Type.INT64);
            return cast(T)(_int64());
        }

        T get(T)() inout if (isGeneralType!(T,uint) ) {
            check(Type.UINT32);
            return cast(T)(_uint32());
        }

        T get(T)() inout if (isGeneralType!(T,ulong) ) {
            check(Type.UINT64);
            return cast(T)(_uint64());
        }

        T get(T)() inout if (isGeneralType!(T,double)) {
            check(Type.DOUBLE);
            return cast(T)(_double());
        }

        T get(T)() inout if (isGeneralType!(T,float)) {
            check(Type.FLOAT);
            return cast(T)(_float());
        }

        T get(T)() inout if (is(TypedefType!T : const(Date))) {
            check(Type.DATE);
            return cast(T)SysTime(_int64());
        }

        T get(T)() inout if (is(TypedefType!T : const(DateTime))) {
            check(Type.TIMESTAMP);
            return cast(T)SysTime(_int64());
        }

        T get(T)() inout if (is(TypedefType!T : const(ObjectId))) {
            check(Type.OID);
            return cast(T)(ObjectId(value));
        }

        /**
         * Returns an DOCUMENT document.
         */
        Document get(T)() inout if (is(TypedefType!T == Document)) {
            if ( (type != Type.DOCUMENT) && (type != Type.ARRAY) ) {
                check(Type.DOCUMENT);
            }
            return Document(value);
        }

        /**
         * Returns an DOCUMENT[] document array.
         */
        version(none)
        Document[] get(T)() inout if (is(TypedefType!T == Document[])) {
            check(Type.BINARY);
            check(getSubtype!(TypedefType!T));
            Document[] docs;

            @trusted
                void build_document_array(immutable(ubyte[]) data) {
                if ( data.length ) {
                    immutable len=*cast(uint*)(data.ptr);
                    immutable from=uint.sizeof;
                    immutable to=uint.sizeof+len;
                    docs~=Document(data[from..to]);
                    build_document_array(data[to..$]);
                }
            }
            build_document_array(value);
            return docs;
        }

        @trusted T get(T)() inout if (isSubType!(TypedefType!T)) {
            alias BaseT=TypedefType!T;
            static if ( is(BaseT : immutable(U[]), U) ) {
                static if ( is(BaseT : immutable(ubyte[]) ) ) {
                    return binary_buffer;
                }
                else if ( (type == Type.BINARY ) && ( subtype == getSubtype!BaseT ) )  {
                    auto buf=binary_buffer;
                    .check(buf.length % U.sizeof == 0, format("The size of binary subtype '%s' should be a mutiple of %d but is %d", subtype, U.sizeof, buf.length));
                    return cast(BaseT)(buf.ptr[0..buf.length]);
                }
            }
            else {
                static assert(0, "Only immutable type is supported not "~T.stringof);
            }
            throw new BSONException(format("Invalide type expected '%s' but the type used is '%s'", subtype, T.stringof));
            assert(0, "Should never go here! Unsupported type "~T.stringof);
        }

        version(none)
            @trusted
            T get(T)() inout if ( is(TypedefType!T : immutable(ubyte)[]) ) {
            if ( type == Type.BINARY)  {
                return binary_buffer;
            }
            throw new BSONException(format("Invalide type expected '%s' but the type used is '%s'", to!string(subtype), T.stringof));
            assert(0, "Should never go here! Unsupported type "~T.stringof);
        }


    }

    @property @trusted const pure nothrow {
            int as(T)() if (is(T == int)) {
                switch (type) {
                case Type.INT32:
                    return _int32();
                case Type.UINT32:
                    return cast(int)_uint32();
                case Type.INT64:
                    return cast(int)_int64();
                case Type.DOUBLE:
                    return cast(int)_double();
                case Type.FLOAT:
                    return cast(int)_float();
                default:
                    return 0;
                }
            }

            int as(T)() if (is(T == uint)) {
                switch (type) {
                case Type.INT32:
                    return cast(uint)_int32();
                case Type.UINT32:
                    return _uint32();
                case Type.INT64:
                    return cast(uint)_int64();
                case Type.DOUBLE:
                    return cast(uint)_double();
                case Type.FLOAT:
                    return cast(uint)_float();
                default:
                    return 0;
                }
            }

            long as(T)() if (is(T == long)) {
                switch (type) {
                case Type.INT32:
                    return _int32();
                case Type.UINT32:
                    return _uint32();
                case Type.INT64:
                    return _int64();
                case Type.UINT64:
                    return cast(long)_uint64();
                case Type.DOUBLE:
                    return cast(long)_double();
                case Type.FLOAT:
                    return cast(long)_float();
                default:
                    return 0;
                }
            }


            ulong as(T)() if (is(T == ulong)) {
                switch (type) {
                case Type.INT32:
                    return _int32();
                case Type.UINT32:
                    return _uint32();
                case Type.INT64:
                    return cast(ulong)_int64();
                case Type.UINT64:
                    return _uint64();
                case Type.DOUBLE:
                    return cast(ulong)_double();
                case Type.FLOAT:
                    return cast(ulong)_float();
                default:
                    return 0;
                }
            }

            double as(T)() if (is(T == double)) {
                switch (type) {
                case Type.INT32:
                    return cast(double)_int32();
                case Type.UINT32:
                    return cast(double)_uint32();
                case Type.INT64:
                    return cast(double)_int64();
                case Type.UINT64:
                    return cast(double)_uint64();
                case Type.DOUBLE:
                    return _double();
                case Type.FLOAT:
                    return cast(double)_float();
                default:
                    return 0;
                }
            }

            float as(T)() if (is(T == float))
            {
                switch (type) {
                case Type.INT32:
                    return cast(float)_int32();
                case Type.UINT32:
                    return cast(float)_uint32();
                case Type.INT64:
                    return cast(float)_int64();
                case Type.UINT64:
                    return cast(float)_uint64();
                case Type.DOUBLE:
                    return cast(float)_double();
                case Type.FLOAT:
                    return _float();
                default:
                    return 0;
                }
            }
        }

    // TODO: Add more BSON specified type accessors, e.g.  BINARY

    @property @trusted const nothrow
        {
            Tuple!(string, string) regex() pure
            {
                immutable start1  = 1 + rawKeySize;
                immutable pattern = cast(string)_data[start1..$];
                immutable length1 = strlen(pattern.ptr);
                immutable start2  = start1 + length1 + 1;
                immutable flags   = cast(string)_data[start2..$];
                immutable length2 = strlen(flags.ptr);
                return typeof(return)(pattern[start1..start1 + length1],
                    flags[start2..start2 + length2]);
            }


            string str() pure
            {
                return cast(string)value[4..$ - 1];
            }
            alias str dbPointer;


            Date date()
            {
                return cast(Date)SysTime(_int64());
            }


            DateTime timestamp()
            {
                return cast(DateTime)SysTime(_int64());
            }


            string codeWScope() pure
            {
                return cast(string)value[8..$];
            }


            string codeWScopeData() pure
            {
                immutable code = codeWScope;
                return code[code.length + 1..$];
            }


            immutable(ubyte[]) binData() pure
            {
                return value[5..$];
            }
        }


    @safe
    bool opEquals(ref const Element other) const pure nothrow {
        size_t s = size;
        if (s != other.size) {
            return false;
        }
        return _data[0..s] == other._data[0..s];
    }


    @safe
    int opCmp(ref const Element other) const pure nothrow {
        int typeDiff = canonicalType - other.canonicalType;
        if (typeDiff < 0) {
            return -1;
        }
        else if (typeDiff > 0) {
            return 1;
        }
        return compareValue(this, other);
    }


    @safe
    string toString() const {
        return toInfo(true, true);
    }

    @trusted
    string toInfo(bool includeKey = false, bool full = false) const {
        string result;
        if (!isEod && includeKey) {
            result = key ~ " : ";
        }

        with(Type) final switch (type) {
            case MIN:
                result ~= "MinKey";
                break;
            case MAX:
                result ~= "MaxKey";
                break;
            case TRUNC:
                result ~= "Trunc";
                break;
            case NONE:
                result ~= "End of Document";
                break;
            case UNDEFINED:
                result ~= "UNDEFINED";
                break;
            case NULL:
                result ~= "null";
                break;
            case BOOLEAN:
                result ~= to!string(_boolean());
                break;
            case INT32:
                result ~= to!string(_int32());
                break;
            case UINT32:
                result ~= to!string(_uint32());
                break;
            case INT64:
                result ~= to!string(_int64());
                break;
            case UINT64:
                result ~= to!string(_uint64());
                break;
            case DOUBLE:
                result ~= to!string(_double());
                break;
            case FLOAT:
                result ~= to!string(_float());
                break;
            case DATE:
                result ~= "new Date(" ~ date.toString() ~ ")";
                break;
            case TIMESTAMP:
                result ~= "Timestamp " ~ timestamp.toString();
                break;
            case OID:
                auto oid = get!ObjectId;
                result ~= "ObjectId(" ~ oid.toString() ~ ")";
                break;
            case DOCUMENT:
                //result ~= DOCUMENT.toFormatString(false, full);
                break;
            case ARRAY:
                //result ~= DOCUMENT.toFormatString(true, full);
                break;
            case JS_CODE_W_SCOPE:
                result ~= "codeWScope(" ~ codeWScope ~ ")";
                // TODO: Add codeWScopeObject
                break;
            case STRING, SYMBOL, JS_CODE:
                // TODO: Support ... representation with bool = true
                result ~= '"' ~ str ~ '"';
                break;
            case BINARY:
                enum max_display_size=80;
                if ( binary_buffer.length > max_display_size ) {
                    result ~= binary_buffer[0..max_display_size/2].toHexString~
                        "..."~
                        binary_buffer[max_display_size/2+1..$].toHexString;
                }
                else {
                    result ~= binary_buffer.toHexString;
                }
                break;
            case DBPOINTER:
                result ~= "DBRef(" ~ str ~ ")";
                break;
            case REGEX:
                immutable re = regex;
                result ~= "/" ~ re.field[0] ~ "/" ~ re.field[1];
                break;
            case NATIVE_DOCUMENT:
                result ~= "NativeDoc("~_data.length.to!string~")";
                break;
            case NATIVE_STRING_ARRAY:
                assert(0, "Not implemented");
            case NATIVE_ARRAY:
                assert(0, "Not implemented");
            case NATIVE_BSON_ARRAY:
                assert(0, "Not implemented");
            }

        return result;
    }

    unittest {
        // { "obj" : { "x" : 10 } }
        immutable(ubyte)[] data = [
            0x16,  0x00,  0x00,  0x00,
            0x03,  0x6F,  0x62,  0x6A,  0x00,  0x0C,  0x00,  0x00,  0x00,  0x10,  0x78,  0x00,  0x0A,  0x00,  0x00,  0x00,  0x00,  0x00,
            ];
        auto doc = Document(data);
        { // hasElement
            assert(doc.hasElement("obj"));
            assert(doc["obj"].isDocument);
        }
        {
            auto objElem = doc["obj"];
            auto subobj=doc["obj"].get!Document;
            assert(subobj["x"].get!int == 10);
        }
    }

private:
//    @trusted
    void check(Type t) const /* pure */ {
        if (t != type) {
            string typeName = to!string(t); // why is to! not pure?
            string message;
            if (isEod) {
                message = format("Field not found: expected type = %s ", typeName);
            }
            else {
                message = format("Wrong type for field: [%s].type != %s  expected %s",
                    key, typeName, to!string(type),
                    ) ;
            }
            throw new BSONException(message);
        }
    }

    void check(BinarySubType t) const /* pure */ {
        if (t != subtype) {
            string typeName = to!string(t); // why is to! not pure?
            string message;
            if (isEod) {
                message = "Field not found: expected subtype = " ~ typeName;
            }
            else {
                message = "Wrong subtype for field: " ~ key ~ " != " ~ typeName ~ " expected " ~ to!string(type) ;
            }
            throw new BSONException(message);
        }
    }

    @trusted const pure nothrow {
        bool _boolean() {
            return value[0] == 0 ? false : true;
        }


        int _int32() {
            return *cast(int*)(value.ptr);
        }

        uint _uint32() {
            return *cast(uint*)(value.ptr);
        }


        long _int64() {
            return *cast(long*)(value.ptr);
        }

        ulong _uint64() {
            return *cast(ulong*)(value.ptr);
        }


        double _double() {
            return *cast(double*)(value.ptr);
        }

        float _float() {
            return *cast(float*)(value.ptr);
        }
    }


    @property const pure nothrow {
        @safe size_t rawKeySize() {
            return key.length + 1;  // including null character termination
        }

        @trusted uint bodySize() {
            return *cast(uint*)(_data[1 + rawKeySize..$].ptr);
        }
    }
}


unittest {
    struct ETest {
        ubyte[] data;
        Type    type;
        string  key;
        ubyte[] value;
        bool    isTrue;
        bool    isNumber;
        bool    isSimple;
    }

    Element test(ref const ETest set, string msg) {
        auto amsg = "Assertion failure(" ~ msg ~ " type unittest)";
        auto elem = Element(set.data.idup);

        assert(elem.type      == set.type,         amsg);
        assert(elem.key       == set.key,          amsg);
        assert(elem.keySize   == set.key.length,   amsg);
        assert(elem.value     == set.value,        amsg);
        assert(elem.valueSize == set.value.length, amsg);
        assert(elem.isTrue    == set.isTrue,       amsg);
        assert(elem.isNumber  == set.isNumber,     amsg);
        assert(elem.isSimple  == set.isSimple,     amsg);

        return elem;
    }

    { // EOD element
        ubyte[] data = [];
        ETest   set  = ETest(data, Type.NONE, null, null, false, false, false);

        assert(test(set, "EOD").isEod);
    }
    { // {"hello": "world"} elemement
        ubyte[] data = [0x02, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x06, 0x00, 0x00, 0x00, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x00, 0x00, 0x1f];
        auto    set  = ETest(data, Type.STRING, "hello", data[7..$ - 2], true, false, true);
        auto    elem = test(set, "UTF8 STRING");

        assert(elem.str  == "world");
        assert(elem.size == data.length - 2);  // not including extra space
    }

    immutable size_t keyOffset = 3;

    { // {"k": false} elemement
        ubyte[] data = [0x08, 0x6b, 0x00, 0x00];
        ETest   set  = ETest(data, Type.BOOLEAN, "k", data[keyOffset..$], false, false, true);

        assert(!test(set, "Boolean false").get!bool);
    }
    { // {"k": true} elemement
        ubyte[] data = [0x08, 0x6b, 0x00, 0x01];
        ETest   set  = ETest(data, Type.BOOLEAN, "k", data[keyOffset..$], true, false, true);

        assert(test(set, "Boolean true").get!bool);
    }
    { // {"k": int.max} elemement
        { // true
            ubyte[] data = [0x10, 0x6b, 0x00, 0xff, 0xff, 0xff, 0x7f];
            ETest   set  = ETest(data, Type.INT32, "k", data[keyOffset..$], true, true, true);

            assert(test(set, "32bit integer").get!int == int.max);
        }
        { // false
            ubyte[] data = [0x10, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00];
            ETest   set  = ETest(data, Type.INT32, "k", data[keyOffset..$], false, true, true);

            assert(test(set, "32bit integer").get!int == 0);
        }
    }
    { // {"k": long.min} elemement
        { // true
            ubyte[] data = [0x12, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80];
            ETest   set  = ETest(data, Type.INT64, "k", data[keyOffset..$], true, true, true);

            assert(test(set, "64bit integer").get!long == long.min);
        }
        { // false
            ubyte[] data = [0x12, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
            ETest   set  = ETest(data, Type.INT64, "k", data[keyOffset..$], false, true, true);

            assert(test(set, "64bit integer").get!long == 0);
        }
    }
    { // {"k": 10000.0} elemement
        { // true
            ubyte[] data = [0x01, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x88, 0xc3, 0x40];
            ETest   set  = ETest(data, Type.DOUBLE, "k", data[keyOffset..$], true, true, true);

            assert(test(set, "Floating point").get!double == 10000.0f);
        }
        { // false
            ubyte[] data = [0x01, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
            ETest   set  = ETest(data, Type.DOUBLE, "k", data[keyOffset..$], false, true, true);

            assert(test(set, "Floating point").get!double == 0.0f);
        }
    }
    { // {"k": Date or DateTime(2011/09/26...)} elemement
        immutable time = 1316968892700L;
        {
            ubyte[] data = [0x09, 0x6b, 0x00, 0x1c, 0x89, 0x76, 0xa1, 0x32, 0x01, 0x00, 0x00];
            ETest   set  = ETest(data, Type.DATE, "k", data[keyOffset..$], true, false, true);

            assert(test(set, "Date").get!Date == cast(Date)SysTime(time));
        }
        {
            ubyte[] data = [0x11, 0x6b, 0x00, 0x1c, 0x89, 0x76, 0xa1, 0x32, 0x01, 0x00, 0x00];
            ETest   set  = ETest(data, Type.TIMESTAMP, "k", data[keyOffset..$], true, false, false);

            assert(test(set, "Timestamp").get!DateTime == cast(DateTime)SysTime(time));
        }
    }
    { // {"k": ObjectId(...)} elemement
        ubyte[]  data = [0x07, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0xff, 0xff, 0xff, 0xff];
        ETest    set  = ETest(data, Type.OID, "k", data[keyOffset..$], true, false, true);

        auto check = ObjectId(long.min, uint.max);
        assert((test(set, "ObjectId").get!ObjectId) == check );
    }
    { // No content elemements, null, MinKey, MaxKey
        foreach (i, type; [Type.NULL, Type.MIN, Type.MAX]) {
            ubyte[] data = [type, 0x6b, 0x00];
            ETest   set  = ETest(data, type, "k", data[keyOffset..$], i > 0);

            test(set, to!string(type));
        }
    }

    // TODO: Add other type tests
}


@trusted
int wellOrderedCompare(ref const Element lhs, ref const Element rhs, bool considerKey = true) pure nothrow
{
    int r = lhs.canonicalType - rhs.canonicalType;
    if (r != 0 && (!lhs.isNumber() || !rhs.isNumber()))
        return r;

    if (considerKey) {
        r = strcmp(lhs.key.ptr, rhs.key.ptr);
        if (r != 0)
            return r;
    }

    return compareValue(lhs, rhs);
}


@trusted
int compareValue(ref const Element lhs, ref const Element rhs) pure nothrow {
    with(Type) final switch (lhs.type) {
        case MIN, MAX, TRUNC, NONE, UNDEFINED,  NULL:
            auto r = lhs.canonicalType - rhs.canonicalType;
            if (r < 0)
                return -1;
            return r == 0 ? 0 : 1;
        case DOUBLE:
        Ldouble:
            import std.math;

            double l = lhs.as!double;
            double r = rhs.as!double;

            if (l < r)
                return -1;
            if (l == r)
                return 0;
            if (isNaN(l))
                return isNaN(r) ? 0 : -1;
            return 1;
        case FLOAT:
            if (rhs.type == FLOAT) {
                immutable l = lhs.as!float;
                immutable r = rhs.as!float;

                if (l < r)
                    return -1;
                return l == r ? 0 : 1;
            }
            goto Ldouble;
        case INT32:
            if (rhs.type == INT32) {
                immutable l = lhs.as!int;
                immutable r = rhs.as!int;

                if (l < r)
                    return -1;
                return l == r ? 0 : 1;
            }
            goto Ldouble;
        case UINT32:
            if (rhs.type == UINT32) {
                immutable l = lhs.as!int;
                immutable r = rhs.as!int;

                if (l < r)
                    return -1;
                return l == r ? 0 : 1;
            }
            goto Ldouble;
        case INT64:
            if (rhs.type == INT64) {
                immutable l = lhs.as!long;
                immutable r = rhs.as!long;

                if (l < r)
                    return -1;
                return l == r ? 0 : 1;
            }
            goto Ldouble;
        case UINT64:
            if (rhs.type == UINT64) {
                immutable l = lhs.as!ulong;
                immutable r = rhs.as!ulong;

                if (l < r)
                    return -1;
                return l == r ? 0 : 1;
            }
            goto Ldouble;
        case STRING, SYMBOL, JS_CODE:
            import std.algorithm;

            immutable ls = lhs.bodySize;
            immutable rs = rhs.bodySize;
            immutable r  = memcmp(lhs.str.ptr, rhs.str.ptr, min(ls, rs));

            if (r != 0) {
                return r;
            }
            else if (ls < rs) {
                return -1;
            }
            return ls == rs ? 0 : 1;
        case DOCUMENT,  ARRAY:
            // TODO
            return 0;
        case BINARY:
            immutable ls = lhs.bodySize;
            immutable rs = rhs.bodySize;

            if ((ls - rs) != 0)
                return ls - rs < 0 ? -1 : 1;
            return memcmp(lhs.value[4..$].ptr, rhs.value[4..$].ptr, ls + 1);  // +1 for subtype
        case OID:
            return memcmp(lhs.value.ptr, rhs.value.ptr, 12);
        case BOOLEAN:
            return lhs.value[0] - rhs.value[0];
        case DATE, TIMESTAMP:
            // TODO: Fix for correct comparison
            // Following comparison avoids non-pure function call.
            immutable l = lhs._int64();
            immutable r = rhs._int64();

            if (l < r)
                return -1;
            return l == r ? 0 : 1;
        case REGEX:
            immutable re1 = lhs.regex;
            immutable re2 = rhs.regex;

            immutable r = strcmp(re1.field[0].ptr, re2.field[0].ptr);
            if (r != 0)
                return r;
            return strcmp(re1.field[1].ptr, re2.field[1].ptr);
        case DBPOINTER:
            immutable ls = lhs.valueSize;
            immutable rs = rhs.valueSize;

            if ((ls - rs) != 0)
                return ls - rs < 0 ? -1 : 1;
            return memcmp(lhs.str.ptr, rhs.str.ptr, ls);
        case JS_CODE_W_SCOPE:
            auto r = lhs.canonicalType - rhs.canonicalType;
            if (r != 0)
                return r;
            r = strcmp(lhs.codeWScope.ptr, rhs.codeWScope.ptr);
            if (r != 0)
                return r;
            r = strcmp(lhs.codeWScopeData.ptr, rhs.codeWScopeData.ptr);
            if (r != 0)
                return r;
            return 0;
        case NATIVE_DOCUMENT, NATIVE_ARRAY, NATIVE_BSON_ARRAY, NATIVE_STRING_ARRAY:
            assert(0, "A native document can not be compared");
        }
}


unittest
{
    auto oidElem   = Element(cast(immutable(ubyte[]))[0x07, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0xff, 0xff, 0xff, 0xff]);
    auto strElem   = Element(cast(immutable(ubyte[]))[0x02, 0x6b, 0x00, 0x06, 0x00, 0x00, 0x00, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x00]);  // world
    auto intElem   = Element(cast(immutable(ubyte[]))[0x10, 0x6b, 0x00, 0xff, 0xff, 0xff, 0x7f]);  // int.max
    auto longElem  = Element(cast(immutable(ubyte[]))[0x12, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);  // 0
    auto trueElem  = Element(cast(immutable(ubyte[]))[0x08, 0x6b, 0x00, 0x01]);
    auto dateElem  = Element(cast(immutable(ubyte[]))[0x09, 0x6b, 0x00, 0x1c, 0x89, 0x76, 0xa1, 0x32, 0x01, 0x00, 0x00]);
    auto someElems = [longElem, strElem, oidElem, trueElem, dateElem];  // canonicalType order

    { // MinKey
        auto minKeyElem = Element(cast(immutable(ubyte[]))[Type.MIN, 0x6b, 0x00]);
        auto expect_1 = Element(cast(immutable(ubyte[]))[Type.MIN, 0x6b, 0x00]);
        assert(minKeyElem == expect_1);
        foreach (ref elem; someElems)
            assert(minKeyElem < elem);

        auto expect_2= Element(cast(immutable(ubyte[]))[Type.MIN, 0x6b, 0x00]);
        assert(!(minKeyElem < expect_2));

        auto expect_3= Element(cast(immutable(ubyte[]))[Type.MIN, 0x6a, 0x00]);
        assert(!(minKeyElem < expect_3));  // not consider key
        auto expect_4= Element(cast(immutable(ubyte[]))[Type.MIN, 0x6c, 0x00]);
        assert(wellOrderedCompare(minKeyElem, expect_4) < 0);
        auto expect_5=Element(cast(immutable(ubyte[]))[Type.MIN, 0x6c, 0x00]);
        assert(wellOrderedCompare(minKeyElem, expect_5, false) == 0);
    }
    { // str
        foreach (ref elem; someElems[0..1])
            assert(strElem > elem);
        foreach (ref elem; someElems[2..$])
            assert(strElem < elem);

        auto strElem2 = Element(cast(immutable(ubyte[]))[0x02, 0x6b, 0x00, 0x05, 0x00, 0x00, 0x00, 0x62, 0x73, 0x6f, 0x6e, 0x00]);  // bson
        auto strElem3 = Element(cast(immutable(ubyte[]))[0x02, 0x6c, 0x00, 0x05, 0x00, 0x00, 0x00, 0x62, 0x73, 0x6f, 0x6e, 0x00]);  // bson

        assert(strElem > strElem2);
        assert(strElem > strElem3);
        assert(wellOrderedCompare(strElem, strElem3) < 0);
        assert(wellOrderedCompare(strElem, strElem3, false) > 0);
    }
    { // int
        foreach (ref elem; someElems[1..$])
            assert(intElem < elem);

        auto intElem2 = Element(cast(immutable(ubyte[]))[0x10, 0x6c, 0x00, 0x00, 0x00, 0x00, 0x00]);  // 0

        assert(intElem > intElem2);
        assert(intElem > longElem);
        assert(wellOrderedCompare(intElem, intElem2) < 0);
    }
    { // long
        foreach (ref elem; someElems[1..$])
            assert(longElem < elem);

        auto longElem2 = Element(cast(immutable(ubyte[]))[0x12, 0x6a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]);  // long.min

        assert(intElem  > longElem2);
        assert(longElem > longElem2);
        assert(wellOrderedCompare(longElem, longElem2) > 0);
    }
    { // boolean
        foreach (ref elem; someElems[0..2])
            assert(trueElem > elem);
        foreach (ref elem; someElems[4..$])
            assert(trueElem < elem);

        auto falseElem = Element(cast(immutable(ubyte[]))[0x08, 0x6c, 0x00, 0x00]);

        assert(falseElem < trueElem);
        assert(wellOrderedCompare(falseElem, trueElem) > 0);
        assert(wellOrderedCompare(falseElem, trueElem, false) < 0);
    }
    { // MaxKey
        auto maxKeyElem = Element(cast(immutable(ubyte[]))[Type.MAX, 0x6b, 0x00]);
        auto expect_1=Element(cast(immutable(ubyte[]))[Type.MAX, 0x6b, 0x00]);
        assert(maxKeyElem == expect_1);

        foreach (ref elem; someElems)
            assert(maxKeyElem > elem);

        auto expect_2=Element(cast(immutable(ubyte[]))[Type.MAX, 0x6b, 0x00]);
        assert(!(maxKeyElem < expect_2));

        auto expect_3=Element(cast(immutable(ubyte[]))[Type.MAX, 0x6a, 0x00]);
        assert(!(maxKeyElem < expect_3));  // not consider key

        auto expect_4=Element(cast(immutable(ubyte[]))[Type.MAX, 0x6c, 0x00]);
        assert(wellOrderedCompare(maxKeyElem, expect_4) < 0);
        auto expect_5=Element(cast(immutable(ubyte[]))[Type.MAX, 0x6c, 0x00]);
        assert(wellOrderedCompare(maxKeyElem, expect_5, false) == 0);
    }

    // TODO: Add other type tests
}


/**
 * Exception type used by tagion.utils.BSON module
 */
@safe
class BSONException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

@safe
void check(bool flag, string msg, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new BSONException(msg, file, line);
    }
}


/**
 * The BSON ObjectId Datatype
 *
 * See_Also:
 *  $(LINK2 http://www.mongodb.org/display/DOCS/Object+IDs, Object IDs)
 */
struct ObjectId {
private:
    // ObjectId is 12 bytes
    union
    {
        ubyte[12] data;

        struct
        {
            long a;
            uint b;
        }

        struct
        {
            ubyte[4] time;
            ubyte[3] machine;
            ushort   pid;
            ubyte[3] inc;
        }
    }


    // ourMachine shoulde be immutable
    // immutable static ubyte[3] ourMachine;
    // See: http://dusers.dip.jp/modules/forum/index.php?topic_id=104#post_id399
    __gshared static ubyte[3] ourMachine;


    @trusted
    shared static this() {
        // import std.md5;  // TODO: Will be replaced with std.digest
        import std.digest.md;
        import std.socket;

        ubyte[16] digest;

        digest=md5Of(Socket.hostName());
        //sum(digest, Socket.hostName());
        ourMachine[] = digest[0..3];
    }

    unittest {
        ObjectId oid;
        oid.initialize();

        assert(oid.machine == ourMachine);
    }


public:
    @property
    static uint machineID() nothrow
        {
            static union MachineToID
            {
                ubyte[4] machine;
                uint     id;
            }

            MachineToID temp;
            temp.machine[0..3] = ourMachine;
            return temp.id;
        }


    @safe pure nothrow
        {
            this(in ubyte[] bytes)
                in
                {
                    assert(bytes.length == 12, "The length of bytes must be 12");
                }
            body
            {
                data[] = bytes;
            }


            this(long a, uint b)
            {
                this.a = a;
                this.b = b;
            }


            this(in string hex)
                in
                {
                    assert(hex.length == 24, "The length of hex string must be 24");
                }
            body
            {
                data[] = fromHex(hex);
            }
        }


    @trusted
    void initialize()
        {
            import std.process;

            { // time
                uint   t = cast(uint)Clock.currTime().toUnixTime();
                ubyte* p = cast(ubyte*)&t;
                time[0]  = p[3];
                time[1]  = p[2];
                time[2]  = p[1];
                time[3]  = p[0];
            }

            // machine
            machine = ourMachine;

            // pid(or thread id)
            static if (__VERSION__ >= 70) {
                pid = cast(ushort)thisProcessID();
            }
            else {
                pid = cast(ushort)getpid();
            }

            { // inc
                //See: http://d.puremagic.com/issues/show_bug.cgi?id = 6670
                //import core.atomic;
                /* shared */ __gshared static uint counter;
                //atomicOp!"+="(counter, 1u);
                uint   i = counter++;
                ubyte* p = cast(ubyte*)&i;
                inc[0]   = p[2];
                inc[1]   = p[1];
                inc[2]   = p[0];
            }
        }


    @safe
    bool opEquals(ref const ObjectId other) const pure nothrow {
        return data == other.data;
    }


    @safe
    string toString() const pure nothrow {
        return data.toHex();
    }

    @safe
    immutable(ubyte)[12] id() const pure nothrow {
        return data;
    }
}


unittest
{
    { // ==
        string hex = "ffffffffffffff7fffffffff";

        auto oid1 = ObjectId(long.max, uint.max);
        auto oid2 = ObjectId(hex);
        assert(oid1 == oid2);
        assert(oid1.toString() == hex);
        assert(oid2.toString() == hex);

        ObjectId oid;
        oid.initialize();
        assert(oid.machineID > 0);
    }
    { // !=
        auto oid1 = ObjectId(long.max, uint.max);
        auto oid2 = ObjectId(long.max,  int.max);

        assert(oid1 != oid2);
    }
    { // internal data
        ObjectId oid = ObjectId("000102030405060708090a0b");

        assert(oid.data == [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b]);
    }
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
    return (is(T:const(bool)[]))|
        (is(T:const(ubyte)[])) |
        (is(T:const(int)[])) |
        (is(T:const(uint)[])) |
        (is(T:const(long)[])) |
        (is(T:const(ulong)[])) |
        (is(T:const(double)[])) |
        (is(T:const(float)[])) |
        (is(T:const(ubyte)[]));
}

static
BinarySubType getSubtype(T)() {
    with(BinarySubType) {
        static if (is(T:const(bool)[])) {
            return BOOLEAN_array;
        }
        else static if (is(T:const(int)[])) {
            return INT32_array;
        }
        else static if (is(T:const(uint)[])) {
            return UINT32_array;
        }
        else static if (is(T:const(long)[])) {
            return INT64_array;
        }
        else static if (is(T:const(ulong)[])) {
            return UINT64_array;
        }
        else static if (is(T:const(double)[])) {
            return DOUBLE_array;
        }
        else static if (is(T:const(float)[])) {
            return FLOAT_array;
        }
        else static if (is(T:const(ubyte)[])) {
            return GENERIC;
        }
        else  {
            static assert(0, "Unsupport type "~T.stringof);
        }
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


@safe
class BSON(bool key_sort_flag=true, bool one_time_write=false) {

    package Type _type;
    package BinarySubType subtype;
    private BSON members; // List of members
    private immutable(char)[] _key;
//    public bool typedarray; // Start standard type array as Binary data (like double[])
    public bool no_duble; // This will prevent the BSON object from creating double or multiple members
    struct CodeScope {
        immutable(char)[] code;
        BSON document;
    }
    private struct _Date  {
        short _year  = 1;
        Month _month = Month.jan;
        ubyte _day   = 1;
    }

    immutable(char)[] key() @safe pure nothrow const {
        return _key;
    }

//    private bool const_pointer;

    union Value {
        double number;
        float number32;
        immutable(char)[] text;
        bool boolean;
        BSON document;
//        const(BSON)* document_ptr;
        ObjectId oid;
        private _Date _date;
        @property final Date date() const {
            return Date(_date._year, _date._month, _date._day);
        }
        @property final void date(ref const(Date) d) nothrow {
            _date._year=d.year;
            _date._month=d.month;
            _date._day=d.day;
        }

//        Date date;
        int int32;
        long int64;
        uint uint32;
        ulong uint64;
        immutable(char)[][2] regex;
        CodeScope codescope;
        immutable(ubyte)[] binary;
        immutable(bool)[] bool_array;
        immutable(int)[] int32_array;
        immutable(uint)[] uint32_array;
        immutable(long)[] int64_array;
        immutable(ulong)[] uint64_array;
        immutable(float)[] float_array;
        immutable(double)[] double_array;
        string[] text_array;
        BSON[] bson_array;
        Document[] document_array;

/*
  immutable(char)[][] atext;
  int[] aint32;
  immuatble(long[] aint64;
*/
    };
    this() {
        _type=Type.DOCUMENT;
    }
    @property
    @trusted
    size_t id() const pure nothrow {
        return cast(size_t)(cast(void*)this);
    }
    @trusted
    auto get(T)() inout {
        alias BaseType=TypedefType!T;
        static if (is(immutable BaseType == immutable double)) {
            assert(_type == Type.DOUBLE);
            return cast(T)(value.number);
        }
        else static if (is(BaseType:string)) {
            assert(_type == Type.STRING);
            return cast(T)(value.text);
        }
        else static if (is(BaseType==bool)) {
            assert(_type == Type.BOOLEAN);
            return cast(T)(value.boolean);
        }
        else static if (is(BaseType:const(BSON))) {
            assert(_type == Type.DOCUMENT);
            return cast(T)(value.document);
        }
        else static if (is(BaseType:const(Document))) {
            assert(_type == Type.NATIVE_DOCUMENT);
            return Document(assumeUnique(value.binary));
        }
        else static if (is(BaseType==ObjectId)) {
            assert(_type == Type.OID);
            return cast(T)(value.oid);
        }
        else static if (is(BaseType==int)) {
            assert(_type == Type.INT32);
            return cast(T)(value.int32);
        }
        else static if (is(BaseType==uint)) {
            assert(_type == Type.UINT32);
            return cast(T)(value.uint32);
        }
        else static if (is(BaseType==long)) {
            assert(_type == Type.INT64);
            return cast(T)(value.int64);
        }
        else static if (is(BaseType==ulong)) {
            assert(_type == Type.UINT64);
            return cast(T)(value.uint64);
        }
        else static if (is(BaseType==Date)) {
            assert(_type == Type.DATE);
            return cast(T)(value.date);
        }
        else static if (is(BaseType==CodeScope)) {
            assert(_type == Type.JS_CODE_SCOPE);
            return cast(T)(value.codescope);
        }
        else static if (is(BaseType:string[])) {
            assert(_type == Type.NATIVE_STRING_ARRAY);
            return cast(T)(value.text_array);
        }
        else static if (is(BaseType:const(ubyte)[])) {
            assert(_type == Type.BINARY);
            return cast(T)(value.binary);
        }
        else static if (is(BaseType:const(bool)[])) {
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.BOOLEAN_array);
            return cast(T)(value.bool_array);
        }
        else static if (is(BaseType:const(int)[])) {
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.INT32_array);
            return cast(T)(value.int32_array);
        }
        else static if (is(BaseType:const(uint)[])) {
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.UINT32_array);
            return cast(T)(value.uint32_array);
        }
        else static if (is(BaseType:const(ulong)[])) {
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.UINT64_array);
            return cast(T)(value.uint64_array);
        }
        else static if (is(BaseType:const(long)[])) {
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.INT64_array);
            return cast(T)(value.int64_array);
        }
        else static if (is(BaseType:const(float)[])) {
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.FLOAT_array);
            return cast(T)(value.float_array);
        }
        else static if (is(BaseType:const(double)[])) {
            assert(_type == Type.ARRAY);
            assert(subtype == BinarySubType.DOUBLE_array);
            return cast(T)(value.double_array);
        }
        // else static if (is(BaseType:U[],U) && isSomeString!U) {
        //     assert(_type == Type.ARRAY);
        //     assert(subtype == BinarySubType.STRING_array);
        //     return cast(T)(value.text_array);
        // }
        else static if (is(BaseType==BSON[])) {
            assert(_type == Type.NATIVE_BSON_ARRAY);
            return cast(T)(value.bson_array);
        }
        else static if (is(BaseType==Document[])) {
            assert(_type == Type.NATIVE_ARRAY);
            return cast(T)(value.document_array);
        }
        else {
            static assert(0, "Type "~T.stringof~ "is not supported by this function");
        }


    }
    package Value value;
    bool isDocument() {
        return ( (type == Type.DOCUMENT) || (type == Type.ARRAY) );
    }

    import std.stdio;
    @trusted
    protected void append(T)(Type type, string key, T x, BinarySubType binary_subtype=BinarySubType.GENERIC) {
        alias BaseT=TypedefType!T;
        static if (one_time_write) {
            if ( hasElement(key) ) {
                throw new BSONException(format("Member '%s' already exist, BSON is a 'one time write' type", key));
            }
        }
//        static if(__traits(compiles, x.length) ) {
            if ( key == "public" ) {
                writefln("append %s type=%s subtype=%s T=%s BaseT=%s",
                    key, type, binary_subtype, T.stringof, BaseT.stringof);
            }
//        }
        bool result=false;
        BSON elm=new BSON;
        scope(success) {
            if ( no_duble ) {
                remove(key);
            }
            elm._type=type;
            elm.subtype=binary_subtype;
            elm._key=key;
            elm.members=members;
            members=elm;
        }
        with (Type) {
            final switch (type) {
            case MIN:
            case NONE:
            case MAX:
            case TRUNC:
                break;
            case DOUBLE:
            case FLOAT:
                static if (is(BaseT:double)) {
                    elm.value.number=cast(double)x;
                    result=true;
                }
                break;
            case REGEX:
                static if (is(BaseT==U[],U)) {
                    if (x.length>1) {
                        immutable(char)[][2] regex;
                        static if (is(U==immutable(char)[])) {
                            regex[0]=x[0];
                            regex[1]=x[1];
                            elm.value.regex=regex;
                            result=true;
                        }
                        else static if (is(U:const(char)[])) {
                            regex[0]=x[0].idup;
                            regex[1]=x[1].idup;
                            elm.value.regex=regex;
                            result=true;
                        }
                    }
                }
                break;
            case STRING:
            case JS_CODE:
            case SYMBOL:
                static if (is(BaseT==string)) {
                    elm.value.text=x;
                    result=true;
                }
                break;
            case JS_CODE_W_SCOPE:
                static if (is(BaseT==CodeScope)) {
                    elm.value.codescope=x;
                    result=true;
                }
                break;
            case DOCUMENT:
                static if (is(BaseT:BSON)) {
                    elm.value.document=x;
                    result=true;
                }
                else static if (is(BaseT:const(BSON))) {
                    elm.value.document=cast(BSON)x;
                    result=true;
                }
                else {
                    assert(0, "Unsupported type "~T.stringof~" not a valid "~to!string(type));
                }
                break;
            case ARRAY:
                static if (is(BaseT==BSON)) {
                    elm.value.document=x;
                    result=true;
                }
                else static if (is(BaseT:const(BSON))) {
                    elm.value.document=cast(BSON)x;
                    result=true;
                }
                else static if (is(BaseT:string[])) {
                    elm.value.text_array=x;
                }
                else {
                    assert(0, "Unsupported type "~T.stringof~" does not seem to be a valid native array");
                }
                break;
            case BINARY:
                static if (is(BaseT:U[],U)) {

                    writefln("BaseT=%s U=%s x=%s", BaseT.stringof, U.stringof, x);
                    static if (is(U==immutable ubyte)) {
                        elm.value.binary=cast(BaseT)x;
                    }
                    else static if (is(U==immutable int)) {
                        elm.value.int32_array=cast(BaseT)x;
                    }
                    else static if (is(U==immutable uint)) {
                        elm.value.uint32_array=cast(BaseT)x;
                    }
                    else static if (is(U==immutable long)) {
                        elm.value.int64_array=cast(BaseT)x;
                    }
                    else static if (is(U==immutable ulong)) {
                        elm.value.uint64_array=cast(BaseT)x;
                    }
                    else static if (is(U==immutable double)) {
                        elm.value.double_array=cast(BaseT)x;
                    }
                    else static if (is(U==immutable float)) {
                        elm.value.float_array=cast(BaseT)x;
                    }
                    else static if (is(U==immutable bool)) {
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
            case UNDEFINED:
                result=true;
                break;
            case OID:
                static if (is(BaseT==ObjectId)) {
                    result=true;
                    elm.value.oid=x;
                }
                break;
            case BOOLEAN:
                static if (is(BaseT:const(long)) || is(BaseT:const(ulong)) ) {
                    elm.value.boolean=x!=0;
                    result=true;
                }
                else static if (is(BaseT:const(real))) {
                    elm.value.boolean=x!=0.0;
                    result=true;
                }
                else static if (is(BaseT:const(bool))) {
                    elm.value.boolean=cast(bool)x;
                    result=true;
                }
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
            case DBPOINTER:
                throw new BSONException(format("Unsupported BSON type '%s' for key '%s' '",type.to!string, key.idup));
                break;
            case INT32:
                static if (is(BaseT:int)) {
                    elm.value.int32=cast(int)x;
                    result=true;
                }
                break;
            case UINT32:
                static if (is(BaseT:uint)) {
                    elm.value.uint32=cast(uint)x;
                    result=true;
                }
                break;
            case INT64:
                static if (is(BaseT:long)) {
                    elm.value.int64=cast(long)x;
                    result=true;
                }
                break;
            case UINT64:
                static if (is(BaseT:ulong)) {
                    elm.value.uint64=cast(ulong)x;
                    result=true;
                }
                break;
            case TIMESTAMP:
                static if (is(BaseT==DateTime)) {
                    auto st=SysTime(x);
                    elm.value.int64=st.stdTime;
                    result=true;
                }
                break;
            case NATIVE_BSON_ARRAY:
                static if ( is(BaseT:const(BSON[])) ) {
                    elm.value.bson_array=x;
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
            .check(result, format("Unmatch type %s at %s. Expected  BSON type '%s' %s", T.stringof, key, type,
                    (type == BINARY)?format("subtype '%s'", subtype):""));
        }
    }

    void opIndexAssign(T, Index)(T x, const Index index) if (isIntegral!Index) {
        opIndexAssign(x, index.to!string);
    }
    import std.stdio;

    void opIndexAssign(T)(T x, string key) {
        alias BaseType=TypedefType!T;
        if ( key == "public" ) {
            writefln("append key=%s T=%s BaseType=%s",
                key, T.stringof, BaseType.stringof);
        }
        static if (isGeneralType!(T, bool)) {
            append(Type.BOOLEAN, key, x);
        }
        else static if (isGeneralType!(T, int)) {
            append(Type.INT32, key, x);
        }
        else static if (isGeneralType!(T, long)) {
            append(Type.INT64, key, x);
        }
        else static if (isGeneralType!(T, double)) {
            append(Type.DOUBLE, key, x);
        }
        else static if (isGeneralType!(T, uint)) {
            append(Type.UINT32, key, x);
        }
        else static if (isGeneralType!(T, ulong)) {
            append(Type.UINT64, key, x);
        }
        else static if (isGeneralType!(T, float)) {
            append(Type.FLOAT, key, x);
        }
        else static if (isGeneralType!(T, string)) {
            append(Type.STRING, key, x);
        }
        else static if (isGeneralType!(T, Date)) {
            append(Type.DATE, key, x);
        }
        else static if (isGeneralType!(T, DateTime)) {
            append(Type.TIMESTAMP, key, x);
        }
        else static if (is(BaseType:string[])) {
            append(Type.NATIVE_STRING_ARRAY, key, x);
        }
        else static if (is(BaseType:const(BSON))) {
            append(Type.DOCUMENT, key, x);
        }
        else static if (is(BaseType:const(Document)) ) {
            append(Type.NATIVE_DOCUMENT, key, x);
        }
        else static if (is(BaseType:const(Document[])) ) {
            append(Type.NATIVE_ARRAY, key, x);
        }
        else static if (is(BaseType:const(BSON[])) ) {
            append(Type.NATIVE_BSON_ARRAY, key, x);
        }
        else static if (isSubType!BaseType) {
            append(Type.BINARY, key, x, getSubtype!BaseType);
        }
        else static if (is(BaseType:U[],U)) {
            append(Type.ARRAY, key, x);
        }
        else static if (is(BaseType==enum) && is(BaseType : const(uint)) ) {
            append(Type.UINT32, key, cast(uint)x);
        }
        else {
            static assert(0, "opIndexAssign does not support type "~T.stringof~" use append member function instead");
        }
    }

    unittest { // opIndexAssign type test
        auto bson=new BSON;
        {
            const bool x=true;
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.BOOLEAN);
        }

        {
            const int x=-42;
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.INT32);
        }

        {
            const long x=-42;
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.INT64);
        }

        {
            const double x=-42.42;
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.DOUBLE);
        }

        {
            const uint x=42;
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.UINT32);
        }

        {
            const ulong x=42;
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.UINT64);
        }

        {
            const float x=-42.42;
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.FLOAT);
        }

        {
            const string x="some_text";
            enum type=typeof(x).stringof;
            bson[type]=x;
            assert(bson[type].type == Type.STRING);
        }

    }

    void setNull(string key) {
        append(Type.NULL, key, null);
    }

    unittest { // bool bug-fix test
        auto bson=new BSON;
        const x=true;
        bson["bool"]=x;
        immutable data=bson.serialize;

        auto doc=Document(data);
        auto value=doc["bool"];
        assert(value.type == Type.BOOLEAN);
        assert(value.get!bool == true);
    }

    unittest { // Assign Document[]
        BSON bson;
        Document[] docs;
        bson=new BSON;
        bson["int_0"]=0;
        docs~=Document(bson.serialize);
        bson=new BSON;
        bson["int_1"]=1;
        docs~=Document(bson.serialize);
        bson=new BSON;
        bson["int_2"]=2;
        docs~=Document(bson.serialize);

        bson=new BSON;
        bson["docs"]=docs;


        auto doc=Document(bson.serialize);

        auto doc_docs=doc["docs"].get!Document;

        assert(doc_docs.length == 3);
        assert(doc_docs.keys == ["0", "1", "2"]);
        assert(doc_docs.indices == [0, 1, 2]);
        foreach(uint i;0..3) {
            assert(doc_docs.hasElement(i.to!string));
            assert(doc_docs.hasElement(i));
            auto e=(i.to!string in doc_docs);
            auto d=doc_docs[i].get!Document;
            assert(d["int_"~i.to!string].get!int == i);
        }
    }

    const(BSON) opIndex(const(char)[] key) const {
        auto iter=Iterator!(const(BSON), false)(this);
        foreach(b;iter) {
            if ( b.key == key ) {
                return b;
                break;
            }
        }
        throw new BSONException("Member '"~key.idup~"' not defined");
        assert(0);
    }

    BSON opIndex(const(char)[] key) {
        foreach(b;this) {
            if ( b.key == key ) {
                return b;
                break;
            }
        }
        throw new BSONException("Member '"~key.idup~"' not defined");
        assert(0);
    }

    bool hasElement(const(char)[] key) const {
        auto iter=Iterator!(const(BSON), false)(this);
        foreach(b;iter) {
            if ( b.key == key ) {
                return true;
                break;
            }
        }
        return false;
    }

    Type type() pure const nothrow {
        return _type;
    }

    string typeName() pure const  {
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
            case NATIVE_DOCUMENT:
                result~=format("%s %s", to!string(_type), value.document_array.length);
                break;
            case NATIVE_ARRAY:
                result~=format("%s %s", to!string(_type), value.binary.length);
                break;
            case NATIVE_BSON_ARRAY:
                result~=format("%s %s", to!string(_type), value.bson_array.length);
                break;
            case NATIVE_STRING_ARRAY:
                result~=format("%s %s", to!string(_type), value.text_array.length);
            }
        return result;
    }

    string_t toText(string_t=string)() {
        string_t object_toText(BSON obj) {
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
            case UNDEFINED:
                return "undefined";
            case NULL:
                return "null";
            case DOUBLE:
                return to!string_t(value.number);
            case FLOAT:
                return to!string_t(value.number32);
            case STRING:
            case REGEX:
            case JS_CODE:
            case SYMBOL:
                return to!string_t('"'~value.text~'"') ;
            case JS_CODE_W_SCOPE:
                return to!string_t("["~value.codescope.code~", "~to!string(value.codescope.document.id)~"]");
            case DOCUMENT:
            case ARRAY:
                return object_toText(this);
            case BINARY:
                return binary_toText();
            case OID:
                return to!string_t(toHex(value.oid.id));
            case BOOLEAN:
                return to!string_t(value.boolean);
            case DATE:
                return to!string_t('"'~value.date.toString~'"');
            case DBPOINTER:
                return to!string_t('"'~to!string(_type)~'"');
            case INT32:
                return to!string_t(value.int32);
            case UINT32:
                return to!string_t(value.uint32);
            case INT64:
                return '"'~to!string_t(value.int64)~'"';
            case UINT64:
                return '"'~to!string_t(value.uint64)~'"';
            case TIMESTAMP:
                return '"'~to!string_t(value.int64)~'"';
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
        else static if (is(T:const(BSON))) {
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
                    case NATIVE_BSON_ARRAY:
                        e.append_native_array!(BSON[])(DOCUMENT, data);
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
        BSON bson1=new BSON;


        bson1["int"]=3;
        bson1["number"]=1.7;
        bson1["bool"]=true;
        bson1["text"]="sometext";

        assert(!bson1.duble);
        {
            auto iter=bson1.iterator;
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
        data1=bson1.serialize();

        {
            auto doc=Document(data1);
            assert(doc.hasElement("int"));
            assert(doc.hasElement("bool"));
            assert(doc.hasElement("number"));
            assert(doc.hasElement("text"));
            assert(doc.keys.length == 4);
            assert(doc["int"].get!int == 3);
            assert(doc["bool"].get!bool);
            assert(doc["number"].get!double == 1.7);
            assert(doc["text"].get!string == "sometext");

        }

        BSON bson2=new BSON;
        bson2["x"] = 10;
        bson1["obj"]=bson2;

        data1=bson1.serialize();
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

    unittest { // Test of serializing of a cost(BSON)
        auto stream(const(BSON) b) {
            return b.serialize;
        }
        {
            auto bson = new BSON;
            bson["x"] = 10;
            bson["s"] = "text";
            auto data_const=stream(bson);
            assert(data_const == bson.serialize);
        }
        { // const(BSON) member
            auto bson1=new BSON;
            auto bson2=new BSON;
            auto sub_bson=new BSON;
            sub_bson["x"]=10;
            bson1["num"]=42;
            bson2["num"]=42;
            bson1["obj"]=cast(BSON)sub_bson;
            bson2["obj"]=sub_bson;
            assert(bson1.serialize == bson2.serialize);
            assert(stream(bson1) == bson2.serialize);
            assert(bson1.serialize == stream(bson2));
        }
    }

    unittest {
        // Test D array types
        BSON bson;
        { // Boolean array
            immutable bools=[true, false, true];
            bson=new BSON;
            bson["bools"]=bools;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("bools"));
            auto subarray=doc["bools"].get!(typeof(bools));

            assert(subarray[0] == bools[0]);
            assert(subarray[1] == bools[1]);
            assert(subarray[2] == bools[2]);
        }

        { // Int array
            immutable(int[]) int32s=[7, -9, 13];
            bson=new BSON;
            bson["int32s"]=int32s;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("int32s"));
            auto subarray=doc["int32s"].get!(typeof(int32s));

            assert(subarray[0] == int32s[0]);
            assert(subarray[1] == int32s[1]);
            assert(subarray[2] == int32s[2]);
        }

        { // Unsigned int array
            immutable(uint[]) uint32s=[7, 9, 13];
            bson=new BSON;
            bson["uint32s"]=uint32s;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("uint32s"));
            auto subarray=doc["uint32s"].get!(typeof(uint32s));

            assert(subarray[0] == uint32s[0]);
            assert(subarray[1] == uint32s[1]);
            assert(subarray[2] == uint32s[2]);
        }

        { // Long array
            immutable(long[]) int64s=[7, 9, -13];
            bson=new BSON;
            bson["int64s"]=int64s;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("int64s"));
            auto subarray=doc["int64s"].get!(typeof(int64s));

            assert(subarray[0] == int64s[0]);
            assert(subarray[1] == int64s[1]);
            assert(subarray[2] == int64s[2]);
        }

        { // Unsigned long array
            immutable(ulong[]) uint64s=[7, 9, 13];
            bson=new BSON;
            bson["uint64s"]=uint64s;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("uint64s"));
            auto subarray=doc["uint64s"].get!(typeof(uint64s));

            assert(subarray[0] == uint64s[0]);
            assert(subarray[1] == uint64s[1]);
            assert(subarray[2] == uint64s[2]);
        }

        { // double array
            immutable(double[]) doubles=[7.7, 9.9, 13.13];
            bson=new BSON;
            bson["doubles"]=doubles;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("doubles"));
            auto subarray=doc["doubles"].get!(typeof(doubles));

            assert(subarray[0] == doubles[0]);
            assert(subarray[1] == doubles[1]);
            assert(subarray[2] == doubles[2]);
        }


        { // float array
            immutable(float[]) floats=[7.7, 9.9, 13.13];
            bson=new BSON;
            bson["floats"]=floats;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("floats"));
            auto subarray=doc["floats"].get!(typeof(floats));

            assert(subarray[0] == floats[0]);
            assert(subarray[1] == floats[1]);
            assert(subarray[2] == floats[2]);
        }

        { // string array
            string[] strings=["Hej", "med", "dig"];
            bson=new BSON;
            bson["strings"]=strings;

            auto doc=Document(bson.serialize);
            assert(doc.hasElement("strings"));
            auto subarray=doc["strings"].get!Document;

            assert(subarray[0].get!string == strings[0]);
            assert(subarray[1].get!string == strings[1]);
            assert(subarray[2].get!string == strings[2]);
        }

        {
            BSON[] bsons;
            bson=new BSON;
            bson["x"]=10;
            bsons~=bson;
            bson=new BSON;
            bson["y"]="kurt";
            bsons~=bson;
            bson=new BSON;
            bson["z"]=true;
            bsons~=bson;
            bson=new BSON;

            bson["bsons"]=bsons;

            auto data=bson.serialize;

            auto doc=Document(bson.serialize);

            assert(doc.hasElement("bsons"));

            auto subarray=doc["bsons"].get!Document;
            assert(subarray[0].get!Document["x"].get!int == 10);
            assert(subarray[1].get!Document["y"].get!string == "kurt");
            assert(subarray[2].get!Document["z"].get!bool == true);
        }
    }

    unittest  {
        // Buffer as binary arrays
        BSON bson;
        {

            bson=new BSON;
//            bson.typedarray=true;
            { // Typedarray int32
                immutable(int[]) int32s= [ -7, 9, -13];
                bson["int32s"]=int32s;
                auto doc = Document(bson.serialize);


                assert(doc.hasElement("int32s"));
                auto element=doc["int32s"];
                assert(element.get!(immutable(int)[]).length == int32s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])int32s);
                assert(element.get!(immutable(int)[]) == int32s);
            }

            { // Typedarray uint32
                immutable(uint[]) uint32s= [ 7, 9, 13];
                bson["uint32s"]=uint32s;
                auto doc = Document(bson.serialize);

                assert(doc.hasElement("uint32s"));
                auto element=doc["uint32s"];
                assert(element.get!(immutable(uint)[]).length == uint32s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])uint32s);
                assert(element.get!(immutable(uint)[]) == uint32s);
            }

            { // Typedarray int64
                immutable(long[]) int64s= [ -7_000_000_000_000, 9_000_000_000_000, -13_000_000_000_000];
                bson["int64s"]=int64s;
                auto doc = Document(bson.serialize);

                assert(doc.hasElement("int64s"));
                auto element=doc["int64s"];
                assert(element.get!(immutable(long)[]).length == int64s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])int64s);
                assert(element.get!(immutable(long)[]) == int64s);
            }


            { // Typedarray uint64
                immutable(long[]) uint64s= [ -7_000_000_000_000, 9_000_000_000_000, -13_000_000_000_000];
                bson["uint64s"]=uint64s;
                auto doc = Document(bson.serialize);

                assert(doc.hasElement("uint64s"));
                auto element=doc["uint64s"];
                assert(element.get!(immutable(long)[]).length == uint64s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])uint64s);
                assert(element.get!(immutable(long)[]) == uint64s);
            }

            { // Typedarray number64
                immutable(double[]) number64s= [ -7.7e9, 9.9e-4, -13e200];
                bson["number64s"]=number64s;
                auto doc = Document(bson.serialize);

                assert(doc.hasElement("number64s"));
                auto element=doc["number64s"];
                assert(element.get!(immutable(double)[]).length == number64s.length);
                assert(element.get!(immutable(ubyte)[]) == cast(immutable(ubyte)[])number64s);
                assert(element.get!(immutable(double)[]) == number64s);
            }


            { // Typedarray number32
                immutable(float[]) number32s= [ -7.7e9, 9.9e-4, -13e20];
                bson["number32s"]=number32s;
                auto doc = Document(bson.serialize);

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
        BSON prev;
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
            BSON bson;
            bson=new BSON;
            bson["a"]=3;
            bson["b"]=13;

            assert(bson["a"].get!int == 3);
            bson["a"] = 4;

            uint i;
            foreach(b; bson) {
                if ( b.key == "a" ) {
                    i++;
                }
            }
            assert(i == 2);
            assert(bson.duble);

            bson=new BSON;
            bson.no_duble=true;

            bson["a"] = 3;
            bson["b"] = 13;
            bson["a"] = 4;

            assert(!bson.duble);

            assert(bson["a"].get!int==4);
        }
    }

    Iterator!(BSON, F) iterator(bool F=false)() {
        return Iterator!(BSON, F)(this);
    }

    Iterator!(const(BSON), F) iterator(bool F=false)() const {
        return Iterator!(const(BSON), F)(this);
    }


    @trusted
    protected immutable(ubyte)[] subtype_buffer() const {
        with(BinarySubType) final switch(subtype) {
            case GENERIC:
            case FUNC:
            case BINARY:
            case UUID:
            case MD5:
            case userDefined:
                return value.binary;
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
            case BOOLEAN_array:
                return (cast(immutable(ubyte)*)(value.bool_array.ptr))[0..value.bool_array.length*bool.sizeof];
            case BIGINT, not_defined:
                throw new BSONException("Binary suptype "~to!string(subtype)~" not supported for buffer");

            }

    }

    protected void append_binary(ref immutable(ubyte)[] data) const {
        scope binary=subtype_buffer;
        data~=nativeToLittleEndian(cast(uint)(binary.length));
        data~=cast(ubyte)subtype;
        data~=binary;
    }


    string[] keys() pure const nothrow {
        string[] result;
        void foreach_key(const BSON current) pure nothrow {
            if ( current !is null ) {
                foreach_key(current.members);
                result~=current.key;
            }
        }

        foreach_key(this.members);
        return result;
    }

    uint length() const {
        uint counter;
        auto iter=Iterator!(const(BSON), false)(this);
        foreach(e;iter) {
            counter++;
        }
        return counter;
    }

    unittest {
        // Test keys function
        // and the sorted BSON
        {
            auto bson=new BSON!true;
            auto some_keys=["kurt", "abe", "ole"];
            bson[some_keys[0]]=0;
            bson[some_keys[1]]=1;
            bson[some_keys[2]]=2;
            auto keys=bson.keys;
            // writefln("keys=%s", keys);
            auto data=bson.serialize;
            auto doc=Document(data);
            // writefln("doc.keys=%s", doc.keys);
            // Check that doc.keys are sorted
            assert(doc.keys == ["abe", "kurt", "ole"]);
        }
        {
            BSON!true[] array;
            for(int i=10; i>-7; i--) {
                auto len=new BSON!true;
                len["i"]=i;
                array~=len;
            }
            auto bson=new BSON!true;
            bson["array"]=array;
            auto data=bson.serialize;
            auto doc=Document(data);
            auto doc_array=doc["array"].get!Document;
            foreach(i,k;doc_array.keys) {
                assert(to!string(i) == k);
            }
        }

    }

    int opApply(scope int delegate(BSON bson) @safe dg) {
        return iterator.opApply(dg);
    }

    int opApply(scope int delegate(in string key, BSON bson) @safe dg) {
        return iterator.opApply(dg);
    }

    @safe
    struct Iterator(TBSON, bool key_sort_flag) {
        static assert( is (TBSON:const(BSON)), format("Iterator only supports %s ",BSON.stringof));
        private TBSON owner;
        enum owner_is_mutable=is(TBSON==BSON);
        static if (key_sort_flag) {
            private string[] sorted_keys;
            private string[] current_keys;
        }
        else {
//            static assert(is(TBSON==BSON), format("Non sorted BSON does not support %s", TBSON.stringof));
            static if ( owner_is_mutable ) {
                private BSON current;
            }
            else {
                private TBSON* current;
            }
        }
        this(TBSON owner) {
            this.owner=owner;
            static if ( key_sort_flag ) {
                void keylist(const(BSON) owner) {
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

        TBSON front() {
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

        final int opApply(scope int delegate(TBSON bson) @safe dg) {
            int result;
            for(; !empty; popFront) {
                if ( (result=dg(front))!=0 ) {
                    break;
                }
            }
            return result;
        }

        final int opApply(scope int delegate(in string key, TBSON bson) @safe dg) {
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


unittest { // BSON with const member
    alias GBSON=BSON!true;
    auto bson1=new GBSON;
    auto bson2=new GBSON;
    bson1["hugh"]="Some data";
    bson1["age"]=42;
    bson1["height"]=155.7;

    bson2["obj"]=bson1;
    immutable bson1_data=bson1.serialize;
    immutable bson2_data=bson2.serialize;

    auto doc1=Document(bson1_data);
    auto doc2=Document(bson2_data);

    assert(bson1_data.length == doc1.data.length);
    assert(bson1_data == doc1.data);

    assert(bson2_data.length == doc2.data.length);
    assert(bson2_data == doc2.data);

    void doc_bson_const(GBSON bson, const(GBSON) b) {

        bson["obj"]=b;
    }

    auto bson2c=new GBSON;
    doc_bson_const(bson2c, bson1);

    immutable bson2c_data=bson2c.serialize;
    auto doc2c=Document(bson2c_data);
    assert(bson2c_data == doc2c.data);
    assert(doc2c.data == doc2.data);

}

unittest { // Test of Native Document type
    // The native document type is only used as an internal representation of the Document
    auto bson1=new HBSON;
    auto bson2=new HBSON;
    auto doc_bson=new HBSON;
    doc_bson["int"]=10;
    doc_bson["bool"]=true;
    bson1["obj"]=doc_bson;

    // Test of using native Documnet as a object member
    auto doc=Document(doc_bson.serialize);
    bson2["obj"]=doc;
    auto data1=bson1.serialize;
    // writefln("%s:%d", data1, data1.length);
    auto data2=bson2.serialize;
    // writefln("%s:%d", data2, data2.length);
    assert(data1.length == data2.length);
    assert(data1 == data2);
}
