/**
 * HiBON Document
 *
 */
module hibon.Document;

extern(C):
@nogc:
//import std.format;
import std.meta : AliasSeq, Filter;
import std.traits : isBasicType, isSomeString, isIntegral, isNumeric, getUDAs, EnumMembers, Unqual;
import std.conv : emplace;
import std.algorithm.iteration : map;
import std.algorithm.searching : count;
//import core.stdc.stdio;
//import std.range.primitives : walkLength;

import hibon.utils.BinBuffer;
import hibon.utils.Text;
import hibon.utils.Bailout;
import hibon.utils.Memory;
import LEB128=hibon.utils.LEB128;
import hibon.BigNumber;
import hibon.HiBONBase;

// import std.stdio;
// import std.exception;

static assert(uint.sizeof == 4);

/**
   Document is a lazy handler of HiBON serialized buffer
*/

struct Document {
    @nogc:
    alias Value=ValueT!(false, void, Document); /// HiBON Document value type
    protected immutable(ubyte)[] _data;

    /++
     Gets the internal buffer
     Returns:
     The buffer of the HiBON document
    +/
    immutable(ubyte[]) data() const pure {
        return _data;
    }

    /++
     Creates a HiBON Document from a buffer
     +/
    this(immutable(ubyte[]) data) pure {
        this._data = data;
    }

    /++
     Creates a replicate of a Document from another Document
     The buffer reused not copied
     Params:
     doc is the Document which is replicated
     +/
    this(const Document doc) pure {
        this._data = doc._data;
    }
    /++
     This function returns the HiBON version
     Returns:
     HiBON version
     +/
    uint ver() const {
        if (data.length > ubyte.sizeof) {
            if (data[ubyte.sizeof] == Type.VER) {
                const leb128_version=LEB128.decode!uint(data[ubyte.sizeof..$]);
                return leb128_version.value;
            }
        }
        return 0;
    }

     void surrender() pure {
        _data=null;
    }

    /++
     Makes a copy of $(PARAM doc)
     Returns:
     Document copy
     +/
    void copy(ref const Document doc) {
        emplace(&this, doc);
    }

    @property const {
        bool empty() {
            return data.length < 1;
        }

        uint size() {
            return LEB128.decode!uint(data).value;
        }
    }

    /++
     Counts the number of members in a Document
     Returns:
     Number of members in in the Document
     +/
    @property uint length() const {
        uint count;
        foreach(e; this[]) {
            count++;
        }
        return count;
    }

    /++
     The deligate used by the valid function to report errors
     +/
    alias ErrorCallback = void delegate(scope const(Element) current,
        scope const(Element) previous);

    /++
     This function check's if the Document is a valid HiBON format
     Params:
     If the delegate error_callback is the this function is call when a error occures
     Returns:
     Error code of the validation
     +/
    Element.ErrorCode valid(ErrorCallback error_callback =null) const {
        auto previous=this[];
        bool not_first;
        foreach(ref e; this[]) {
            Element.ErrorCode error_code;
            if (not_first && (key_compare(previous.front.key, e.key) >= 0)) {
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
        }
        return Element.ErrorCode.NONE;
    }

    /++
     Check if a Document format is the correct HiBON format.
     Uses the valid function
     Params:
     true if the Document is inorder
     +/

    bool isInorder() const {
        return valid() is Element.ErrorCode.NONE;
    }

    /++
     Range of the Document
     +/
    struct Range {
        @nogc:
        immutable(ubyte[]) data;
        immutable uint     ver;
    protected:
        size_t            _index;
        Element           _element;
    public:
        this(immutable(ubyte[]) data) {
            this.data = data;
            if (data.length == 0) {
                _index = ubyte.sizeof;
            }
            else {
                _index = LEB128.calc_size(data);
                popFront();
                uint _ver;
                if (!empty && (front.type is Type.VER)) {
                    const leb128_ver=LEB128.decode!uint(data[_index..$]);
                    _ver=leb128_ver.value;
                    _index+=leb128_ver.size;
                }
                ver=_ver;
            }
        }

        this(const Document doc) {
            this(doc.data);
        }

        ~this() {
            emplace(&data, data.init);
        }

        @property pure const {
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
        void popFront() {
            emplace!Element(&_element, data[_index..$]);
            _index += _element.size;
        }
    }

    /++
     Returns:
     A range of Element's
     +/
    Range opSlice() const {
        return Range(data);
    }


    /++
     Returns:
     A range of the member keys in the document
     +/
    KeyRange keys() const {
        return KeyRange(_data);
    }

    protected struct KeyRange {
        @nogc:
        Range range;
        this(immutable(ubyte[]) data) {
            range=Range(data);
        }

        @property bool empty() const pure {
            return range.empty;
        }

        @property  void popFront() {
            range.popFront;
        }

        string front() {
            return range.front.key;
        }
    }

    /++
     The Document must only contain member names which represents an uint number
     Throws:
     an std.conv.ConvException if the keys can not be convert to an uint
     Returns:
     A range of indices of the type of uint in the Document
    +/

    IndexRange indices() const {
        return IndexRange(_data);
    }

    protected struct IndexRange {
        @nogc:
        private {
            Range range;
            bool _error;
        }
        this(immutable(ubyte[]) data) {
            range=Range(data);
        }

        @property bool empty() const pure {
            return range.empty;
        }

        uint front()  {
            const key=range.front.key;
            uint index;
            if (!is_index(key, index)) {
                _error=true;
            }
            return index;
        }

        @property  void popFront() {
            range.popFront;
        }

        @property error() const pure {
            return _error;
        }
    }


    /++
     Check if the Document can be clasified as an Array
     Returns:
     Is true if all the keys in ordred numbers
     +/
    bool isArray() const {
        auto range=indices;
        while(!range.empty) {
            range.popFront;
            if (range.error) {
                return false;
            }
        }
        return true;
    }

    /++
     Returns:
     true if the key exist in the Document
     +/
    bool hasElement(in string key) const {
        return !opBinaryRight!("in")(key).isEod();
    }

    /++
     Returns:
     true if the index exist in the Document
     +/
    bool hasElement(Index)(in Index index) const if (isIntegral!Index) {
        return hasElement(index.to!string);
    }


    /++
     Find the element with key
     Returns:
     Returns the element with the key
     If on element with this key has been found an empty element is returned
     +/
    const(Element) opBinaryRight(string op)(in string key) const if(op == "in") {
        foreach (ref element; this[]) {
            if (element.key == key) {
                return element;
            }
        }
        return Element();
    }

    /++
     Returns:
     The element with the key
     Throws:
     If the element with the key is not found then and HiBONException is thrown
     +/
    const(Element) opIndex(in string key) const {
        auto result=key in this;
        .check(!result.isEod, message("Member named '%s' not found", key));
        return result;
    }

    /++
     Returns:
     The element with the index
     Throws:
     If the element with the key is not found then and HiBONException is thrown
     Or of the key is not an index a std.conv.ConvException is thrown
     +/
    const(Element) opIndex(Index)(in Index index) const if (isIntegral!Index) {
        return opIndex(index.to!string);
    }

    /++
     same as data
     +/
    alias serialize=data;

    /++
     Retruns:
     The number of bytes taken up by the key in the HiBON serialized stream
     +/
    static size_t sizeKey(const(char[]) key) pure {
        return Type.sizeof + ubyte.sizeof + key.length;
    }

    /++
     Calculates the number of bytes taken up by an element in the HiBON serialized stream
     Params:
     type = is the HIBON type
     key = is the key name
     x = is the value
     Returns:
     The number of bytes taken up by the element
     +/
    static size_t sizeT(T)(Type type, string key, const(T) x) pure {
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

    /++
     Append the key to the buffer
     Params:
     buffer = is the target buffer
     type = is the HiBON type
     key = is the member key
     index = is offset index in side the buffer and index with be progressed
     +/
    static void buildKey(ref BinBuffer buffer, Type type, const(char[]) key) {
        buffer.write(type);
        buffer.write(cast(ubyte)(key.length));
        buffer.write(key);
    }

    /++
     Append a full element to a buffer
     Params:
     buffer = is the target buffer
     type = is the HiBON type
     key = is the member key
     x = is the value of the element
     index = is offset index in side the buffer and index with be progressed
     +/
    static void build(T)(ref BinBuffer buffer, Type type, const(char[]) key, const(T) x) {
        buildKey(buffer, type, key);
        static if ( is(T: U[], U) ) {
            immutable size=cast(uint)(x.length*U.sizeof);
            buffer.write(size);
            buffer.write(x);
        }
        else static if (is(T : const Document)) {
            buffer.write(x.data);
        }
        else static if (is(T : const BigNumber)) {
            import std.internal.math.biguintnoasm : BigDigit;
            immutable size=cast(uint)(bool.sizeof+x.data.length*BigDigit.sizeof);
            buffer.write(size);
            buffer.write(x.data);
            buffer.write(x.sign);
        }
        else {
            buffer.write(x);
        }
    }

    /++
     This range is used to generate and range of same type U
     If the Document contains and Array of the elements this range can be used
     Returns:
     Range (Array) of the type U
     +/
    RangeT!U range(T : U[], U)() const {
        return RangeT!U(data);
    }

    ///
    unittest {
        alias TabelRange = Tuple!( ubyte[],  ubyte[], ubyte[]);
        TabelRange tabel_range;

        const(ubyte[3]) tabel_range_0_=[1,2,4];
        tabel_range[0].create(tabel_range_0_);
        const(ubyte[4]) tabel_range_1_=[3,4,5,6];
        tabel_range[1].create(tabel_range_1_);
        const(ubyte[4]) tabel_range_2_=[8,4,2,1];
        tabel_range[2].create(tabel_range_2_);

        scope(exit) {
            foreach(t; tabel_range) {
                t.dispose;
            }
        }

        auto buffer=BinBuffer(0x200); //new ubyte[0x200];
        make(buffer, tabel_range);
//        const doc_buffer = buffer[0..index]; //.idup;
        const doc=Document(buffer.serialize);
        auto tabelR=doc.range!(immutable(ubyte)[][]);
        foreach(t; tabel_range) {
            assert(tabelR.front == t);
            tabelR.popFront;
        }

        auto S=doc.range!(string[]);

        assert(!S.empty);
    }

    struct RangeT(T) {
        @nogc:
        Range range;
        enum EType=Value.asType!T;
        static assert(EType !is Type.NONE, format("Range type %s not supported", T.stringof));
        this(immutable(ubyte)[] data) {
            range = Range(data);
        }

        @property {
            immutable(ubyte[]) data() {
                return range.data;
            }

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
                bool empty() {
                    return range.empty;
                }

                string key() {
                    return range.front.key;
                }
            }
        }
    }



    version(unittest) {
        import std.typecons : Tuple, isTuple;
        import hibon.utils.Basic : basename;
        static private void make(S)(ref BinBuffer buffer, S _struct, size_t count=size_t.max) if (is(S==struct)) {

            const start_index=buffer.length;
            buffer.write(uint.init);
            foreach(i, t; _struct.tupleof) {
                enum name=basename!(_struct.tupleof[i]);
                if ( i is count ) {
                    break;
                }
                static if (name[0] == '_') {
                    enum zero=size_t(0);
                    enum suffix_length=zero.stringof.length-"0".length;
                    enum key=i.stringof[0..$-suffix_length];
                }
                else {
                    enum key = name;
                }

                alias T = typeof(t);
                static if (is(T:U[], U) && isBasicType!U) {
                    enum  E = Value.asType!(immutable(T));
                }
                else {
                    enum  E = Value.asType!T;
                }
                build(buffer, E, key, t);
            }
            buffer.write(Type.NONE);
            const size = cast(uint)(buffer.length - uint.sizeof);
            buffer.write(size, start_index);
        }
    }

    unittest {
        { // Test of null document
            const doc = Document(null);
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        { // Test of empty Document
            auto buffer=BinBuffer(0x200);
            size_t index;
            buffer.write(uint.init);
            buffer.write(Type.NONE);
            buffer.write(uint(1), 0);
            const doc_buffer=buffer[0..index];
            const doc = Document(doc_buffer.serialize);
            assert(doc.length is 0);
            assert(doc[].empty);

        }
    }

    unittest {
        struct Table {
            float FLOAT32;
            double FLOAT64;
            //     BigNumberBIGINT;
            bool  BOOLEAN;
            int   INT32;
            long  INT64;
            uint  UINT32;
            ulong UINT64;
            }
        Table table;
        table.FLOAT32 = 1.23;
        table.FLOAT64 = 1.23e200;
        table.INT32   = -42;
        table.INT64   = -0x0123_3456_789A_BCDF;
        table.UINT32   = 42;
        table.UINT64   = 0x0123_3456_789A_BCDF;
        table.BOOLEAN  = true;
        auto test_table=table.tupleof;

        struct TableArray {
            ubyte[] BINARY;
            float[] FLOAT32_ARRAY;
            double[]FLOAT64_ARRAY;
            int[]   INT32_ARRAY;
            long[]  INT64_ARRAY;
            uint[]  UINT32_ARRAY;
            ulong[] UINT64_ARRAY;
            bool[]  BOOLEAN_ARRAY;
            string  STRING;
        }


        TableArray table_array;
        const(ubyte[3]) binary=[1, 2, 3];
        table_array.BINARY.create(binary);
        const(float[3]) float32_array=[-1.23, 3, 20e30];
        table_array.FLOAT32_ARRAY.create(float32_array);
        const(double[2]) float64_array=[10.3e200, -1e-201];
        table_array.FLOAT64_ARRAY.create(float64_array);
        const(int[4]) int32_array=[-11, -22, 33, 44];
        table_array.INT32_ARRAY.create(int32_array);
        const(long[4]) int64_array=[0x17, 0xffff_aaaa, -1, 42];
        table_array.INT64_ARRAY.create(int64_array);
        const(uint[4]) uint32_array=[11, 22, 33, 44];
        table_array.UINT32_ARRAY.create(uint32_array);
        const(ulong[4]) uint64_array=[0x17, 0xffff_aaaa, 1, 42];
        table_array.UINT64_ARRAY.create(uint64_array);
        const(bool[2]) boolean_array=[true, false];
        table_array.BOOLEAN_ARRAY.create(boolean_array);
        table_array.STRING="Text";//.create(text);

        auto test_table_array=table_array.tupleof;

        scope(exit) {
            foreach(i, t; test_table_array) {
                alias U=typeof(t);
                static if (!is(U==string)) {
                    t.dispose;
                }
            }
        }

        { // Document with simple types
            //test_table.UTC      = 1234;
            { // Document with a single value
                auto buffer=BinBuffer(0x200);
                make(buffer, table, 1);
                //const doc_buffer = buffer[0..index];
                const doc=Document(buffer.serialize);
                assert(doc.length is 1);
                // assert(doc[Type.FLOAT32.stringof].get!float == test_table[0]);
            }

            { // Document including basic types
                auto buffer=BinBuffer(0x200);
                make(buffer, table);
                //              const doc_buffer = buffer[0..index];
                const doc=Document(buffer.serialize);

                auto keys=doc.keys;
                foreach(i, t; table.tupleof) {
                    enum name = basename!(table.tupleof[i]);
                    alias U = immutable(typeof(t));
                    enum  E = Value.asType!U;
                    assert(doc.hasElement(name));
                    const e = doc[name];
                    assert(keys.front == name);
                    assert(e.get!U == test_table[i]);

                    keys.popFront;

                    auto e_in = name in doc;
                    assert(e.get!U == test_table[i]);

                    assert(e.type is E);
                    assert(e.isType!U);

                    static if(E !is Type.BIGINT) {
                        assert(e.isThat!isBasicType);
                    }
                }
            }


            { // Document which includes basic arrays and string
                auto buffer=BinBuffer(0x200);
                make(buffer, table_array);
//                const doc_buffer = buffer[0..index];
                const doc=Document(buffer.serialize);
                foreach(i, t; table_array.tupleof) {
                    enum name = basename!(table_array.tupleof[i]);
                    alias U = immutable(typeof(t));
                    const v = doc[name].get!U;
                    assert(v.length is test_table_array[i].length);
                    assert(v == test_table_array[i]);
                    import traits=std.traits; // : isArray;
                    const e = doc[name];
                    assert(!e.isThat!isBasicType);
                    assert(e.isThat!(traits.isArray));

                }
            }

            { // Document which includes sub-documents
                auto buffer=BinBuffer(0x200);
                auto buffer_subdoc=BinBuffer(0x200);
                make(buffer_subdoc, table);
                const data_sub_doc = buffer_subdoc.serialize;
                const sub_doc=Document(buffer_subdoc.serialize);

                //index = 0;
                uint size;
                buffer.write(uint.init);
                enum doc_name="doc";

                immutable index_before=buffer.length;
                build(buffer, Type.INT32, Type.INT32.stringof, int(42));
                const data_int32 = buffer[index_before..$];

                build(buffer, Type.DOCUMENT, doc_name, sub_doc);
                build(buffer, Type.STRING, Type.STRING.stringof, "Text");

                buffer.write(Type.NONE);

                size = cast(uint)(buffer.length - uint.sizeof);
                buffer.write(size, 0);

                //const doc_buffer = buffer[0..index];
                const doc=Document(buffer.serialize);

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

                    immutable _data=doc[doc_name].get!Document;
                    assert(under_e.size == data_sub_doc.length + Type.sizeof + ubyte.sizeof + doc_name.length);

                    const under_doc = doc[doc_name].get!Document;
                    assert(under_doc.data.length == data_sub_doc.length);

                    auto keys=under_doc.keys;
                    foreach(i, t; table.tupleof) {
                        enum name = basename!(table.tupleof[i]);
                        alias U = typeof(t);
                        enum  E = Value.asType!U;
                        assert(under_doc.hasElement(name));
                        const e = under_doc[name];
                        assert(e.get!U == test_table[i]);
                        assert(keys.front == name);
                        keys.popFront;

                        auto e_in = name in doc;
                        assert(e.get!U == test_table[i]);
                    }
                }


                { // Check opEqual
                    const data_int32_e = Element(data_int32.serialize);
                    assert(doc[Type.INT32.stringof] == data_int32_e);
                }
            }


            { // Test opCall!(string[])
                auto buffer=BinBuffer(0x200);
                //index = 0;
                uint size;
                buffer.write(uint.init);
                const(char[5][3]) texts=["Text1", "Text2", "Text3"];

                foreach(i, text; texts) {
                    auto converter=Text(long.max.stringof.length);
                    converter(i); //Convert i to string like i.to!string;
                    build(buffer, Type.STRING, converter.serialize, text);
                }

                buffer.write(Type.NONE);
                size = cast(uint)(buffer.length - uint.sizeof);
                buffer.write(size, 0);
                //const doc_buffer = buffer[0..index];
                const doc=Document(buffer.serialize);


                auto typed_range = doc.range!(string[])();
                foreach(i, text; texts) {
                    assert(!typed_range.empty);
                    auto converter=Text(ulong.max.stringof.length);
                    converter(i);
                    assert(typed_range.key == converter.serialize);
                    assert(typed_range.index == i);
                    assert(typed_range.front == text);
                    typed_range.popFront;

                }
            }
        }
    }

/**
 * HiBON Element representation
 */
    struct Element {
        @nogc:
        /*
         * -----
         * //data image:
         * +-------------------------------------------+
         * | [Type] | [len] | [key] | [val | unused... |
         * +-------------------------------------------+
         *          ^ type offset(1)
         *                  ^ len(sizeKey)
         *                          ^ sizeKey + 1 + len(sizeKey)
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
            /++
             Retruns:
             true if the elemnt is of T
             +/
            bool isType(T)() {
                enum E = Value.asType!T;
                return (E !is Type.NONE) && (type is E);
            }

            /++
             Returns:
             The HiBON Value of the element
             throws:
             if  the type is invalid and HiBONException is thrown
             +/
            const(Value) value() {
                with(Type)
                TypeCase:
                switch(type) {
                    static foreach(E; EnumMembers!Type) {
                        static if (isHiBONType(E)) {
                        case E:
                            static if (E is Type.DOCUMENT) {
                                immutable byte_size = *cast(uint*)(data[valuePos..valuePos+uint.sizeof].ptr);
                                return Value(Document(data[valuePos..valuePos+uint.sizeof+byte_size]));
                            }
                            else static if (.isArray(E) || (E is Type.STRING)) {
                                alias T = Value.TypeT!E;
                                static if ( is(T: U[], U) ) {
                                    immutable birary_array_pos = valuePos+uint.sizeof;
                                    immutable byte_size = *cast(uint*)(data[valuePos..birary_array_pos].ptr);
                                    immutable len = byte_size / U.sizeof;
                                    return Value((cast(immutable(U)*)(data[birary_array_pos..$].ptr))[0..len]);
                                }
                            }
                            else static if (E is BIGINT) {
                                import std.internal.math.biguintnoasm : BigDigit;
                                immutable birary_array_pos = valuePos+uint.sizeof;
                                immutable byte_size = *cast(uint*)(data[valuePos..birary_array_pos].ptr);
                                immutable len = byte_size / BigDigit.sizeof;
                                auto dig=(cast(BigDigit*)(data[birary_array_pos..$].ptr))[0..len];
                                const sign=data[birary_array_pos+byte_size] !is 0;
                                auto big=BigNumber(dig, sign);
                                return Value(big);
                                //  assert(0, format("Type %s not implemented", E));
                            }
                            else {
                                if (isHiBONType(type)) {
                                    Value* result=cast(Value*)(&data[valuePos]);
                                    return *result;
                                }
                            }
                            break TypeCase;
                        }
                    }
                default:
                    //empty
                }
                .check(0, message("Invalid type %s", type));
                return Value.init;
//                assert(0);
            }

            /++
             Returns:
             the value as the HiBON type Type
             throws:
             if the element does not contain the type E and HiBONException is thrown
             +/
            auto by(Type E)() const {
                .check(type is E, message("Type expected is %s but the actual type is %s", E, type));
                .check(E !is Type.NONE, message("Type is not supported %s the actual type is %s", E, type));
                return value.by!E;

            }

            /++
             Returns:
             the value as the type T
             throws:
             if the element does not contain the type and HiBONException is thrown
             +/
            const(T) get(T)() const {
                enum E = Value.asType!T;
                static assert(E !is Type.NONE, "Unsupported type "~T.stringof);
                return by!E;
            }

            /++
               Tryes to convert the value to the type T.
               Returns:
               true if the function succeeds
            +/
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

            /++
             Returns:
             the index of the key
             throws:
             if the key is not an index an HiBONException is thrown
             +/
            uint index() {
                uint result;
                .check(is_index(key, result), message("Key '%s' is not an index", key));
                return result;
            }

            /++
             Returns:
             true if element key is an index
             +/
            bool isIndex() {
                uint result;
                return is_index(key, result);
            }
        }

        @property const pure {
            /++
             Returns:
             true if the buffer block ends
             +/
            bool isEod() {
                return data.length == 0;
            }

            /++
             Returns:
             the Type of the element
             +/
            Type type() {
                if (isEod) {
                    return Type.NONE;
                }
                return cast(Type)(data[0]);
            }

            /++
             Returns:
             the key length
             +/
            ubyte keyLen() {
                return cast(Type)(data[Type.sizeof]);
            }

            /++
             Returns:
             the key
             +/
            string key() {
                return cast(string)data[KEY_POS..valuePos];
            }

            /++
             Returns:
             the position of the value inside the element buffer
             +/
            uint valuePos() {
                return KEY_POS+keyLen;
            }
        }

        @property const {
            /++
             Returns:
             the size of the element in bytes
             +/
            size_t size() {
                with(Type) {
                TypeCase:
                    switch(type) {
                        static foreach(E; EnumMembers!Type) {
                        case E:
                            static if (isHiBONType(E)) {
                                alias T = Value.TypeT!E;
                                static if ( .isArray(E) || (E is STRING) || (E is DOCUMENT) ) {
                                    immutable binary_array_pos = valuePos+uint.sizeof;
                                    immutable byte_size = *cast(uint*)(data[valuePos..binary_array_pos].ptr);
                                    return binary_array_pos + byte_size;
                                }
                                static if (E is BIGINT) {
                                    immutable binary_array_pos = valuePos+uint.sizeof;
                                    immutable byte_size = *cast(uint*)(data[valuePos..binary_array_pos].ptr);
                                    return binary_array_pos+byte_size;
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
                // import std.format;
                // assert(0, format("Bad type %s", type));
                assert(0);
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

            /++
               Check if the element is valid
               Returns:
               The error code the element.
               ErrorCode.NONE means that the element is valid

            +/
            @trusted ErrorCode valid() {
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
                        return OVERFLOW;
                    }
                    if ( .isArray(type) ) {
                        immutable binary_array_pos = valuePos+uint.sizeof;
                        immutable byte_size = *cast(uint*)(data[valuePos..binary_array_pos].ptr);
                    ArrayTypeCase:
                        switch(type) {
                            static foreach(E; EnumMembers!Type) {
                                static if ( .isArray(E) && !isNative(E) ) {
                                case E:
                                    alias T = Value.TypeT!E;
                                    static if ( is(T == U[], U) ) {
                                        if ( byte_size % U.sizeof !is 0 ) {
                                            return ARRAY_SIZE_BAD;
                                        }
                                    }
                                    break ArrayTypeCase;
                                }
                            }
                        default:
                            // empty
                        }
                    }
                    return NONE;
                }
            }
        }

        @property const pure {
            /++
               Check if the type match That template.
               That template must have one parameter T as followes
               Returns:
               true if the element is the type That
            +/
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
        /++
         Compare two elements
         +/
        bool opEquals(ref const Element other) const {
            immutable s = size;
            if (s !is other.size) {
                return false;
            }
            return data[0..s] == other.data[0..s];
        }
    }
}
