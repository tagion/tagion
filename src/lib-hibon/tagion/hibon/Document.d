/**
 * HiBON Document
 *
 */
module tagion.hibon.Document;


//import std.format;
import std.meta : AliasSeq, Filter;
import std.traits : isBasicType, isSomeString, isIntegral, isNumeric, getUDAs, EnumMembers, Unqual;
import std.conv : to, emplace;
import std.algorithm.iteration : map;
import std.algorithm.searching : count;
import std.range.primitives : walkLength;

//import tagion.Types : decimal_t;

import tagion.Base : isOneOf;
import tagion.Message : message;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONException;

static assert(uint.sizeof == 4);

@safe struct Document {
    alias Value=ValueT!(false, void, Document);
    immutable(ubyte[]) data;

    @disable this();

    this(immutable(ubyte[]) data) pure nothrow {
        this.data = data;
    }

    this(const Document document) nothrow {
        this.data = document.data;
    }

    @trusted
    void copy(ref const Document doc) {
        emplace(&this, doc);
    }

    @property nothrow pure const {
        @safe bool empty() {
            return data.length < 5;
        }

        @trusted uint size() {
            return *cast(uint*)(data[0..uint.sizeof].ptr);
        }
    }

    @property uint length() const {
        return cast(uint)(this[].walkLength);
    }

    alias ErrorCallback = void delegate(scope const(Element) current,
        scope const(Element) previous);

    Element.ErrorCode valid(ErrorCallback error_callback =null) const {
//        const(Element)* previous;
        import std.stdio;
        auto previous=this[];
        bool not_first;
        foreach(ref e; this[]) {
            Element.ErrorCode error_code;
            if(not_first) {
                //   previous.popFront;
                writefln("previous.key=%s", previous.front.key);
            }
            if (not_first && !less_than(previous.front.key, e.key)) {

                writefln("previous.key=%s e.key=%s", previous.front.key, e.key);
                error_code = Element.ErrorCode.KEY_ORDER;
            }
            else if ( e.type is Type.DOCUMENT ) {
                error_code = e.get!(Document).valid(error_callback);
            }
            else {
                error_code = e.valid;
            }
            if ( error_code !is Element.ErrorCode.NONE ) {
                if ( error_callback ) {
                    error_callback(e, previous.front);
                }
                return error_code;
            }
            if(not_first) {
                previous.popFront;
            }
            not_first=true;

            writefln("e.key=%s", e.key);
            // previous=&e;
            writefln("\tprevious.key=%s", previous.front.key);

        }
        return Element.ErrorCode.NONE;
    }

    bool isInOrder() const {
        return valid() is Element.ErrorCode.NONE;
    }

    @safe
    struct Range {
        immutable(ubyte[]) data;
    protected:
        size_t            _index;
        Element           _element;
    public:
        this(immutable(ubyte[]) data) {
            this.data = data;

            if (data.length == 0) {
                _index = 0;
            }
            else {
                _index = uint.sizeof;
                popFront();
            }
        }

        this(const Document doc) {
            this(doc.data);
        }

        @property pure nothrow const {
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
            emplace!Element(&_element, data[_index..$]);
            _index += _element.size;
        }
    }


    Range opSlice() const {
        return Range(data);
    }

    auto keys() const {
        return map!"a.key"(this[]);
    }

    // Throws an std.conv.ConvException if the keys can not be convert to an uint
    auto indices() const {
        return map!"a.key.to!uint"(this[]);
    }

    bool isArray() const {
        auto range=this[];
        bool check_array_index(const uint previous_index) {
            if (!range.empty) {

                uint current_index;
                if (is_index(range.front.key, current_index)) {
                    range.popFront;
                    if (previous_index+1 is current_index) {
                        return check_array_index(current_index);
                    }
                }
                return false;
            }
            return true;
        }
        if (!range.empty) {
            uint previous_index;
            if (is_index(range.front.key, previous_index)) {
                return check_array_index(previous_index);
            }
        }
        return false;
    }

    bool hasElement(in string key) const {

        return !opBinaryRight!("in")(key).isEod();
//        return !opIn_r(key).isEod();
    }

    bool hasElement(Index)(in Index index) const if (isIntegral!Index) {
        return hasElement(index.to!string);
    }

    const(Element) opBinaryRight(string op)(in string key) const if(op == "in") {
        foreach (ref element; this[]) {
            if (element.key == key) {
                return element;
            }
        }
        return Element();
    }

    const(Element) opIndex(in string key) const {
        auto result=key in this;
        .check(!result.isEod, message("Member named '%s' not found", key));
        return result;
    }

    const(Element) opIndex(Index)(in Index index) const if (isIntegral!Index) {
        return opIndex(index.to!string);
    }


    alias serialize=data;

    static size_t sizeKey(string key) pure nothrow {
        return Type.sizeof + ubyte.sizeof + key.length;
    }

    static size_t sizeT(T)(Type type, string key, const(T) x) pure nothrow {
        size_t size = sizeKey(key);
        static if ( is(T: U[], U) ) {
            size += uint.sizeof + (x.length*U.sizeof);
        }
        else static if(is(T : const Document)) {
            size += x.data.length;
        }
        else static if(is(T : const BigNumber)) {
            import std.internal.math.biguintnoasm : BigDigit;
            size += bool.sizeof+uint.sizeof+x.data.length*BigDigit.sizeof;
        }
        else {
            size += T.sizeof;
        }
        return size;
    }

    @trusted
    static void buildKey(ref ubyte[] buffer, Type type, string key, ref size_t index) pure {
        buffer.binwrite(type, &index);
        buffer.binwrite(cast(ubyte)(key.length), &index);
        buffer.array_write(key, index);
    }

    @trusted
    static void build(T)(ref ubyte[] buffer, Type type, string key, const(T) x, ref size_t index) pure {
        buildKey(buffer, type, key, index);
        // buffer.binwrite(type, &index);
        // buffer.binwrite(cast(ubyte)(key.length), &index);
        // buffer.array_write(key, index);
        static if ( is(T: U[], U) ) {
            immutable size=cast(uint)(x.length*U.sizeof);
            buffer.binwrite(size, &index);
            buffer.array_write(x, index);
        }
        else static if (is(T : const Document)) {
            buffer.array_write(x.data, index);
        }
        else static if (is(T : const BigNumber)) {
            import std.internal.math.biguintnoasm : BigDigit;
            immutable size=cast(uint)(bool.sizeof+x.data.length*BigDigit.sizeof);
            buffer.binwrite(size, &index);
            buffer.array_write(x.data, index);
            buffer.binwrite(x.sign, &index);
        }
        else {
            buffer.binwrite(x, &index);
        }
    }

    RangeT!U range(T : U[], U)() const { //if(!isBasicType(U)) {
        return RangeT!U(data);
    }

    unittest {
        alias TabelRange = Tuple!( immutable(ubyte)[],  immutable(ubyte)[], immutable(ubyte)[]);
        TabelRange tabel_range;

        tabel_range[0]=[1,2,4];
        tabel_range[1]=[3,4,5,6];
        tabel_range[2]=[8,4,2,1];

        size_t index;
        auto buffer=new ubyte[0x200];
        index = make(buffer, tabel_range);
        immutable data = buffer[0..index].idup;
        const doc=Document(data);

        auto tabelR=doc.range!(immutable(ubyte)[][]);
        foreach(t; tabel_range) {
            assert(tabelR.front == t);
            tabelR.popFront;
        }

        auto S=doc.range!(string[]);

        assert(!S.empty);
        bool should_fail;
        try {
            auto s=S.front;
        }
        catch (HiBONException e) {
            should_fail=true;
        }

        assert(should_fail);
    }

    @safe struct RangeT(T) {
        Range range;
        enum EType=Value.asType!T;
        static assert(EType !is Type.NONE, format("Range type %s not supported", T.stringof));
        this(immutable(ubyte)[] data) {
            range = Range(data);
        }


        @property {
            void popFront() {
                range.popFront;
            }

            const(T) front() const {
                return range.front.get!T;
            }

            uint index() const {
                return range.front.index;
            }

            const pure {
                bool empty() nothrow {
                    return range.empty;
                }


                string key() nothrow {
                    return range.front.key;
                }

            }
        }
    }

    version(unittest) {
        import std.typecons : Tuple, isTuple;

        static private size_t make(R)(ref ubyte[] buffer, R range, size_t count=size_t.max) if (isTuple!R) {
            size_t index;
            buffer.binwrite(uint.init, &index);
            foreach(i, t; range) {
                if ( i is count ) {
                    break;
                }
                enum name = range.fieldNames[i];
                alias U = range.Types[i];
                enum  E = Value.asType!U;
                build(buffer, E, name, t, index);
            }
            buffer.binwrite(Type.NONE, &index);
            uint size;
            size = cast(uint)(index - uint.sizeof);
            buffer.binwrite(size, 0);
            return index;
        }
    }

    unittest {
        auto buffer=new ubyte[0x200];


        { // Test of null document
            const doc = Document(null);
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        { // Test of empty Document
            size_t index;
            buffer.binwrite(uint.init, &index);
            buffer.binwrite(Type.NONE, &index);
            buffer.binwrite(uint(1), 0);
            immutable data=buffer[0..index].idup;
            const doc = Document(data);
            assert(doc.length is 0);
            assert(doc[].empty);

        }

        alias Tabel = Tuple!(
            float,  Type.FLOAT32.stringof,
            double, Type.FLOAT64.stringof,
            BigNumber, Type.BIGINT.stringof,
            bool,   Type.BOOLEAN.stringof,
            int,    Type.INT32.stringof,
            long,   Type.INT64.stringof,
            uint,   Type.UINT32.stringof,
            ulong,  Type.UINT64.stringof,

//                utc_t,  Type.UTC.stringof
            );

        Tabel test_tabel;
        test_tabel.FLOAT32 = 1.23;
        test_tabel.FLOAT64 = 1.23e200;
        test_tabel.INT32   = -42;
        test_tabel.INT64   = -0x0123_3456_789A_BCDF;
        test_tabel.UINT32   = 42;
        test_tabel.UINT64   = 0x0123_3456_789A_BCDF;
        test_tabel.BOOLEAN  = true;
        test_tabel.BIGINT   = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");

        alias TabelArray = Tuple!(
            immutable(ubyte)[],  Type.BINARY.stringof,
            immutable(float)[],  Type.FLOAT32_ARRAY.stringof,
            immutable(double)[], Type.FLOAT64_ARRAY.stringof,
            immutable(int)[],    Type.INT32_ARRAY.stringof,
            immutable(long)[],   Type.INT64_ARRAY.stringof,
            immutable(uint)[],   Type.UINT32_ARRAY.stringof,
            immutable(ulong)[],  Type.UINT64_ARRAY.stringof,
            immutable(bool)[],   Type.BOOLEAN_ARRAY.stringof,
            string,              Type.STRING.stringof,


            );

        TabelArray test_tabel_array;
        test_tabel_array.BINARY        = [1, 2, 3];
        test_tabel_array.FLOAT32_ARRAY = [-1.23, 3, 20e30];
        test_tabel_array.FLOAT64_ARRAY = [10.3e200, -1e-201];
        test_tabel_array.INT32_ARRAY   = [-11, -22, 33, 44];
        test_tabel_array.INT64_ARRAY   = [0x17, 0xffff_aaaa, -1, 42];
        test_tabel_array.UINT32_ARRAY  = [11, 22, 33, 44];
        test_tabel_array.UINT64_ARRAY  = [0x17, 0xffff_aaaa, 1, 42];
        test_tabel_array.BOOLEAN_ARRAY = [true, false];
        test_tabel_array.STRING        = "Text";

        { // Document with simple types
            //test_tabel.UTC      = 1234;

            size_t index;

            { // Document with a single value
                index = make(buffer, test_tabel, 1);
                immutable data = buffer[0..index].idup;
                const doc=Document(data);
                assert(doc.length is 1);
                // assert(doc[Type.FLOAT32.stringof].get!float == test_tabel[0]);
            }

            { // Document with a single value
                index = make(buffer, test_tabel, 1);
                immutable data = buffer[0..index].idup;
                const doc=Document(data);
//                writefln("doc.length=%d", doc.length);
                assert(doc.length is 1);
                // assert(doc[Type.FLOAT32.stringof].get!BigNumber == test_tabel[0]);
            }

            { // Document including basic types
                index = make(buffer, test_tabel);
                immutable data = buffer[0..index].idup;
                const doc=Document(data);

                auto keys=doc.keys;
                foreach(i, t; test_tabel) {
                    enum name = test_tabel.fieldNames[i];
                    alias U = test_tabel.Types[i];
                    enum  E = Value.asType!U;
                    assert(doc.hasElement(name));
                    const e = doc[name];
                    assert(e.get!U == test_tabel[i]);
                    assert(keys.front == name);
                    keys.popFront;

                    auto e_in = name in doc;
                    assert(e.get!U == test_tabel[i]);

                    assert(e.type is E);
                    assert(e.isType!U);

                    static if(E !is Type.BIGINT) {
                        assert(e.isThat!isBasicType);
                    }
                }
            }

            { // Document which includes basic arrays and string
                index = make(buffer, test_tabel_array);
                immutable data = buffer[0..index].idup;
                const doc=Document(data);
                foreach(i, t; test_tabel_array) {
                    enum name = test_tabel_array.fieldNames[i];
                    alias U   = test_tabel_array.Types[i];
                    const v = doc[name].get!U;
                    assert(v.length is test_tabel_array[i].length);
                    assert(v == test_tabel_array[i]);
                    import traits=std.traits; // : isArray;
                    const e = doc[name];
                    assert(!e.isThat!isBasicType);
                    assert(e.isThat!(traits.isArray));

                }
            }

            { // Document which includes sub-documents
                auto buffer_subdoc=new ubyte[0x200];
                index = make(buffer_subdoc, test_tabel);
                immutable data_sub_doc = buffer_subdoc[0..index].idup;
                const sub_doc=Document(data_sub_doc);

                index = 0;
                uint size;
                buffer.binwrite(uint.init, &index);
                enum doc_name="doc";

                immutable index_before=index;
                build(buffer, Type.INT32, Type.INT32.stringof, int(42), index);
                immutable data_int32 = buffer[index_before..index].idup;

                build(buffer, Type.DOCUMENT, doc_name, sub_doc, index);
                build(buffer, Type.STRING, Type.STRING.stringof, "Text", index);

                buffer.binwrite(Type.NONE, &index);

                size = cast(uint)(index - uint.sizeof);
                buffer.binwrite(size, 0);

                immutable data = buffer[0..index].idup;
                const doc=Document(data);

                { // Check int32 in doc
                    const int32_e = doc[Type.INT32.stringof];
                    assert(int32_e.type is Type.INT32);
                    assert(int32_e.get!int is int(42));
                    assert(int32_e.by!(Type.INT32) is int(42));
                }

                { // Check string in doc )
                    const string_e = doc[Type.STRING.stringof];
                    assert(string_e.type is Type.STRING);
                    const text = string_e.get!string;
                    assert(text.length is "Text".length);
                    assert(text == "Text");
                    assert(text == string_e.by!(Type.STRING));
                }

                { // Check the sub/under document
                    const under_e = doc[doc_name];
                    assert(under_e.key == doc_name);
                    assert(under_e.type == Type.DOCUMENT);
                    assert(under_e.size == data_sub_doc.length + Type.sizeof + ubyte.sizeof + doc_name.length);

                    const under_doc = doc[doc_name].get!Document;
                    assert(under_doc.data.length == data_sub_doc.length);

                    auto keys=under_doc.keys;
                    foreach(i, t; test_tabel) {
                        enum name = test_tabel.fieldNames[i];
                        alias U = test_tabel.Types[i];
                        enum  E = Value.asType!U;
                        assert(under_doc.hasElement(name));
                        const e = under_doc[name];
                        assert(e.get!U == test_tabel[i]);
                        assert(keys.front == name);
                        keys.popFront;

                        auto e_in = name in doc;
                        assert(e.get!U == test_tabel[i]);
                    }
                }

                { // Check opEqual
                    const data_int32_e = Element(data_int32);
                    assert(doc[Type.INT32.stringof] == data_int32_e);
                }
            }

            { // Test opCall!(string[])
                index = 0;
                uint size;
                buffer.binwrite(uint.init, &index);
                auto texts=["Text1", "Text2", "Text3"];
                foreach(i, text; texts) {
                    build(buffer, Type.STRING, i.to!string, text, index);
                }
                buffer.binwrite(Type.NONE, &index);
                size = cast(uint)(index - uint.sizeof);
                buffer.binwrite(size, 0);

                immutable data = buffer[0..index].idup;
                const doc=Document(data);

                auto typed_range = doc.range!(string[])();
                foreach(i, text; texts) {
                    assert(!typed_range.empty);
                    assert(typed_range.key == i.to!string);
                    assert(typed_range.index == i);
                    assert(typed_range.front == text);
                    typed_range.popFront;
                }
            }
        }
    }


/**
 * HiBON element representation
 */
    @safe struct Element {
        /*
         * -----
         * //data image:
         * +-------------------------------------------+
         * | [Type] | [len] | [key] | [val | unused... |
         * +-------------------------------------------+
         *          ^ type offset(1)
         *                  ^ len offset(2)
         *                          ^ keySize + 2
         *                                 ^ size
         *                                             ^ data.length
         *
         */
        immutable(ubyte[]) data;
    public:
        this(immutable(ubyte[]) data) {
            // In this time, Element does not parse a binary data.
            // This is lazy initialization for some efficient.
            this.data = data;
        }

        enum KEY_POS = Type.sizeof + keyLen.sizeof;

        @property const {
            bool isType(T)() {
                enum E = Value.asType!T;
                return (E !is Type.NONE) && (type is E);
            }

            @trusted const(Value*) value() {
                with(Type)
                TypeCase:
                switch(type) {
                    static foreach(E; EnumMembers!Type) {
                        static if (isHiBONType(E)) {
                        case E:
                            static if (E is Type.DOCUMENT) {
                                immutable byte_size = *cast(uint*)(data[valuePos..valuePos+uint.sizeof].ptr);
                                return new Value(Document(data[valuePos..valuePos+uint.sizeof+byte_size]));
                            }
                            else static if (.isArray(E) || (E is Type.STRING)) {
                                alias T = Value.TypeT!E;
                                static if ( is(T: U[], U) ) {
                                    immutable birary_array_pos = valuePos+uint.sizeof;
                                    immutable byte_size = *cast(uint*)(data[valuePos..birary_array_pos].ptr);
                                    immutable len = byte_size / U.sizeof;
                                    return new Value((cast(immutable(U)*)(data[birary_array_pos..$].ptr))[0..len]);
//                                }
                                }
                            }
                            else static if (E is BIGINT) {
                                import std.internal.math.biguintnoasm : BigDigit;
                                immutable birary_array_pos = valuePos+uint.sizeof;
                                immutable byte_size = *cast(uint*)(data[valuePos..birary_array_pos].ptr);
                                immutable len = byte_size / BigDigit.sizeof;
                                immutable dig=(cast(immutable(BigDigit*))(data[birary_array_pos..$].ptr))[0..len];
                                const sign=data[birary_array_pos+byte_size] !is 0;
                                const big=BigNumber(sign, dig);
                                return new Value(big);
                                //  assert(0, format("Type %s not implemented", E));
                            }
                            else {
                                if (isHiBONType(type)) {
                                    return cast(Value*)(data[valuePos..$].ptr);
                                }
                            }
                            break TypeCase;
                        }
                    }
                default:
                    //empty
                }
                .check(0, message("Invalid type %s", type));

                assert(0);
            }

            auto by(Type E)() {
                .check(type is E, message("Type expected is %s but the actual type is %s", E, type));
                .check(E !is Type.NONE, message("Type is not supported %s the actual type is %s", E, type));
                return value.by!E;

            }

            T get(T)() const {
                enum E = Value.asType!T;
                import std.format;
                static assert(E !is Type.NONE, format("Unsupported type %s", T.stringof));
                return by!E;
            }

            /**
               Tryes to convert the value to the type T.
               Returns true if the function succeeds
            */
            bool as(T)(ref T result) {
                switch(type) {
                    static foreach(E; EnumMembers!Type) {
                        static if (isHiBONType(E)) {
                        case E:
                            alias BaseT = Value.TypeT!E;
                            static if (isImplicitlyConvertible!(BaseT, T)) {
                                result=value.get!BaseT;
                                return true;
                            }
                            else static if (__traits(compiles, value.get!(BaseT).to!T)) {
                                result = value.get!(BaseT).to!T;
                            }
                        }
                    }
                }
                return false;
            }

            uint index() {
                uint result;
                .check(is_index(key, result), message("Key '%s' is not an index", key));
                return result;
            }

            bool isIndex() {
                uint result;
                return is_index(key, result);
            }
        }

        @property const pure nothrow {
            bool isEod() {
                return data.length == 0;
            }

            Type type() {
                if (isEod) {
                    return Type.NONE;
                }
                return cast(Type)(data[0]);
            }

            ubyte keyLen() {
                return cast(Type)(data[Type.sizeof]);
            }

            string key() {
                return cast(string)data[KEY_POS..valuePos];
            }

            uint valuePos() {
                return KEY_POS+keyLen;
            }

            @trusted size_t size() {
                with(Type) {
                TypeCase:
                    switch(type) {
                        static foreach(E; EnumMembers!Type) {
                        case E:
                            static if (isHiBONType(E)) {
                                alias T = Value.TypeT!E;
                                static if ( .isArray(E) || (E is STRING) || (E is DOCUMENT) ) {
                                    // static if (isNative(E)) {
                                    //     return 0;
                                    // }
                                    // else {
                                    immutable binary_array_pos = valuePos+uint.sizeof;
                                    immutable byte_size = *cast(uint*)(data[valuePos..binary_array_pos].ptr);
                                    return binary_array_pos + byte_size;
                                    // }
                                }
                                static if (E is BIGINT) {
                                    immutable binary_array_pos = valuePos+uint.sizeof;
                                    immutable byte_size = *cast(uint*)(data[valuePos..binary_array_pos].ptr);
                                    //debug writefln("byte_size=%d", byte_size);
                                    return binary_array_pos+byte_size;

//                                    assert(0, format("Size of %s not supported yet", E));
                                }
                                else {
                                    return valuePos + T.sizeof;
                                }
                            }
                            else static if (isNative(E)) {
                                static if (E is NATIVE_DOCUMENT) {
                                    const doc = Document(data[valuePos..$]);
                                    return valuePos + uint.sizeof + doc.size;
                                }
                            }
                            else static if ( E is Type.NONE ) {
                                return Type.sizeof;
                            }
                            break TypeCase;
                        }
                    default:
                        // empty
                    }
                }
                import std.format;
                assert(0, format("Bad type %s", type));
            }

            enum ErrorCode {
                NONE,           // No errors
                KEY_ORDER,      // Error in the key order
                DOCUMENT_TYPE,  // Warning document type
                TOO_SMALL,      // Data stream is too small to contain valid data
                ILLEGAL_TYPE,   // Use of internal types is illegal
                INVALID_TYPE,   // Type is not defined
                OVERFLOW,       // The specifed data does not fit into the data stream
                ARRAY_SIZE_BAD  // The binary-array size in bytes is not a multipla of element size in the array
            }

            /**
               Check if the element is valid
            */
            @trusted
                ErrorCode valid() {
                enum MIN_ELEMENT_SIZE = Type.sizeof + ubyte.sizeof + char.sizeof + uint.sizeof;

                with(ErrorCode) {
                    if ( type is Type.DOCUMENT ) {
                        return DOCUMENT_TYPE;
                    }
                    if ( data.length < MIN_ELEMENT_SIZE ) {
                        return TOO_SMALL;
                    }
                TypeCase:
                    switch(type) {
                        static foreach(E; EnumMembers!Type) {
                        case E:
                            static if ( (isNative(E) || (E is Type.DEFINED_ARRAY) ) ) {
                                return ILLEGAL_TYPE;
                            }
                            break TypeCase;
                        }
                    default:
                        return INVALID_TYPE;
                    }
                    if ( size > data.length ) {
                        debug {
                            import std.stdio;
                            import std.exception;
                            assumeWontThrow(writefln("size=%d data.length=%d", size, data.length));
                        }
                        return OVERFLOW;
                    }
                    if ( .isArray(type) ) {
                        immutable binary_array_pos = valuePos+uint.sizeof;
                        immutable byte_size = *cast(uint*)(data[valuePos..binary_array_pos].ptr);
                        switch(type) {
                            static foreach(E; EnumMembers!Type) {
                                static if ( .isArray(E) && !isNative(E) ) {
                                case E:
                                    alias T = Value.TypeT!E;
                                    static if ( is(T : U[], U) ) {
                                        if ( byte_size % U.sizeof !is 0 ) {
                                            return ARRAY_SIZE_BAD;
                                        }
                                    }
                                }
                            }
                        default:
                            // empty
                        }
                    }
                    return NONE;
                }
            }

            /**
               Check if the type match That template.
               That template must have one parameter T as followes
               alias That(T) = ...;
            */
            bool isThat(alias That)() {
            TypeCase:
                switch(type) {
                    static foreach(E; EnumMembers!Type) {
                    case E:
                        static if (isHiBONType(E)) {
                            alias T = Value.TypeT!E;
                            return That!T;
                        }
                        break TypeCase;
                    }
                default:
                    // empty
                }
                return false;
            }
        }

        @safe
        bool opEquals(ref const Element other) const {
            immutable s = size;
            if (s !is other.size) {
                return false;
            }
            return data[0..s] == other.data[0..s];
        }
    }

}
