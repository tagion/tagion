/**
 * HiBON Document
 *
 */
module hibon.Document;

extern(C):

//import std.format;
import std.meta : AliasSeq, Filter;
import std.traits : isBasicType, isSomeString, isIntegral, isNumeric, getUDAs, EnumMembers, Unqual;
import std.conv : emplace;
import std.algorithm.iteration : map;
import std.algorithm.searching : count;
import std.range.primitives : walkLength;

//import tagion.Types : decimal_t;

//import tagion.Base : isOneOf;
//import .Message : message;
import hibon.utils.BinBuffer;
import hibon.utils.Text;
import hibon.utils.Bailout;
import hibon.BigNumber;
import hibon.HiBONBase;
//import hibon.HiBONException;

import std.stdio;
import std.exception;

static assert(uint.sizeof == 4);

/**
   Document is a lazy handler of HiBON serialized buffer
*/

struct Document {
    alias Value=ValueT!(false, void, Document); /// HiBON Document value type
    protected immutable(ubyte)[] _data;

    /++
     Gets the internal buffer
     Returns:
     The buffer of the HiBON document
    +/
    immutable(ubyte[]) data() const pure nothrow {
        return _data;
    }

    /++
     Creates a HiBON Document from a buffer
     +/
    this(immutable(ubyte[]) data) pure nothrow {
        this._data = data;
    }

    /++
     Creates a replicate of a Document from another Document
     The buffer reused not copied
     Params:
     doc is the Document which is replicated
     +/
    this(const Document doc) pure nothrow {
        this._data = doc._data;
    }

    /++
     Makes a copy of $(PARAM doc)
     Returns:
     Document copy
     +/

    void copy(ref const Document doc) {
        emplace(&this, doc);
    }

    @property nothrow pure const {
        bool empty() {
            return data.length < 5;
        }

        uint size() {
            return *cast(uint*)(data[0..uint.sizeof].ptr);
        }
    }

    /++
     Counts the number of members in a Document
     Returns:
     Number of members in in the Document
     +/
    @property uint length() const {
        return cast(uint)(this[].walkLength);
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
            if (not_first && !less_than(previous.front.key, e.key)) {
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
    auto keys() const {
        return map!"a.key"(this[]);
    }

    /++
     The Document must only contain member names which represents an uint number
     Throws:
     an std.conv.ConvException if the keys can not be convert to an uint
     Returns:
     A range of indices of the type of uint in the Document
    +/

    auto indices() const {
        return map!(a => to_uint(a.key))(this[]);
    }


    /++
     Check if the Document can be clasified as an Array
     Returns:
     Is true if all the keys in ordred numbers
     +/
    bool isArray() const {
        return .isArray(keys);
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
    static size_t sizeKey(const(char[]) key) pure nothrow {
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

    /++
     Append the key to the buffer
     Params:
     buffer = is the target buffer
     type = is the HiBON type
     key = is the member key
     index = is offset index in side the buffer and index with be progressed
     +/
    static void buildKey(ref BinBuffer buffer, Type type, const(char[]) key, ref size_t index) {
        buffer.write(type, &index);
        buffer.write(cast(ubyte)(key.length), &index);
        buffer.write(key, &index);
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
    static void build(T)(ref BinBuffer buffer, Type type, const(char[]) key, const(T) x, ref size_t index) {
        buildKey(buffer, type, key, index);
        // buffer.binwrite(type, &index);
        // buffer.binwrite(cast(ubyte)(key.length), &index);
        // buffer.array_write(key, index);
        static if ( is(T: U[], U) ) {
            immutable size=cast(uint)(x.length*U.sizeof);
            buffer.write(size, &index);
            buffer.write(x, &index);
        }
        else static if (is(T : const Document)) {
            buffer.write(x.data, &index);
        }
        else static if (is(T : const BigNumber)) {
            import std.internal.math.biguintnoasm : BigDigit;
            immutable size=cast(uint)(bool.sizeof+x.data.length*BigDigit.sizeof);
            buffer.write(size, &index);
            buffer.write(x.data, &index);
            buffer.write(x.sign, &index);
        }
        else {
            buffer.write(x, &index);
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
        alias TabelRange = Tuple!( immutable(ubyte)[],  immutable(ubyte)[], immutable(ubyte)[]);
        TabelRange tabel_range;

        tabel_range[0]=[1,2,4];
        tabel_range[1]=[3,4,5,6];
        tabel_range[2]=[8,4,2,1];

        size_t index;
        auto buffer=BinBuffer(0x200); //new ubyte[0x200];
        index = make(buffer, tabel_range);
        const doc_buffer = buffer[0..index]; //.idup;
        const doc=Document(doc_buffer.serialize);

        auto tabelR=doc.range!(immutable(ubyte)[][]);
        foreach(t; tabel_range) {
            assert(tabelR.front == t);
            tabelR.popFront;
        }

        auto S=doc.range!(string[]);

        assert(!S.empty);
        // bool should_fail;
        // try {
        //     auto s=S.front;
        // }
        // catch (HiBONException e) {
        //     should_fail=true;
        // }

        // assert(should_fail);
    }

    struct RangeT(T) {
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

        static private size_t make(R)(ref BinBuffer buffer, R range, size_t count=size_t.max) if (isTuple!R) {
            size_t index;
            buffer.write(uint.init, &index);
            foreach(i, t; range) {
                if ( i is count ) {
                    break;
                }
                enum name = range.fieldNames[i];
                alias U = range.Types[i];
                enum  E = Value.asType!U;
                build(buffer, E, name, t, index);
            }
            buffer.write(Type.NONE, &index);
            uint size;
            size = cast(uint)(index - uint.sizeof);
            buffer.write(size, 0);
            return index;
        }
    }

    unittest {
        auto buffer=BinBuffer(0x200);


        { // Test of null document
            const doc = Document(null);
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        { // Test of empty Document
            size_t index;
            buffer.write(uint.init, &index);
            buffer.write(Type.NONE, &index);
            buffer.write(uint(1), 0);
            const doc_buffer=buffer[0..index];
            const doc = Document(doc_buffer.serialize);
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
        test_tabel.BIGINT   = BigNumber([42, 17, 3333, 4444], true);

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
                const doc_buffer = buffer[0..index];
                const doc=Document(doc_buffer.serialize);
                assert(doc.length is 1);
                // assert(doc[Type.FLOAT32.stringof].get!float == test_tabel[0]);
            }

            { // Document with a single value
                index = make(buffer, test_tabel, 1);
                const doc_buffer = buffer[0..index];
                const doc=Document(doc_buffer.serialize);
//                writefln("doc.length=%d", doc.length);
                assert(doc.length is 1);
                // assert(doc[Type.FLOAT32.stringof].get!BigNumber == test_tabel[0]);
            }

            { // Document including basic types
                index = make(buffer, test_tabel);
                const doc_buffer = buffer[0..index];
                const doc=Document(doc_buffer.serialize);

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
                const doc_buffer = buffer[0..index];
                const doc=Document(doc_buffer.serialize);
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
                auto buffer_subdoc=BinBuffer(0x200);
                index = make(buffer_subdoc, test_tabel);
                const data_sub_doc = buffer_subdoc[0..index];
                const sub_doc=Document(data_sub_doc.serialize);

                index = 0;
                uint size;
                buffer.write(uint.init, &index);
                enum doc_name="doc";

                immutable index_before=index;
                build(buffer, Type.INT32, Type.INT32.stringof, int(42), index);
                const data_int32 = buffer[index_before..index];

                build(buffer, Type.DOCUMENT, doc_name, sub_doc, index);
                build(buffer, Type.STRING, Type.STRING.stringof, "Text", index);

                buffer.write(Type.NONE, &index);

                size = cast(uint)(index - uint.sizeof);
                buffer.write(size, 0);

                const doc_buffer = buffer[0..index];
                const doc=Document(doc_buffer.serialize);

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
                    const data_int32_e = Element(data_int32.serialize);
                    assert(doc[Type.INT32.stringof] == data_int32_e);
                }
            }

            { // Test opCall!(string[])
                index = 0;
                uint size;
                buffer.write(uint.init, &index);
                auto texts=["Text1", "Text2", "Text3"];

                foreach(i, text; texts) {
                    auto converter=Text(long.max.stringof.length);
                    converter(i); //Convert i to string like i.to!string;
                    build(buffer, Type.STRING, converter.serialize, text, index);
                }

                buffer.write(Type.NONE, &index);
                size = cast(uint)(index - uint.sizeof);
                buffer.write(size, 0);
                const doc_buffer = buffer[0..index];
                const doc=Document(doc_buffer.serialize);


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
            Value value() {
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
                                    return cast(Value)(data[valuePos..$]);
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

        @property const pure nothrow {
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

            /++
             Returns:
             the size of the element in bytes
             +/
            //  version(none)
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
