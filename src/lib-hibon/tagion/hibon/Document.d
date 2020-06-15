/**
 * HiBON Document
 *
 */
module tagion.hibon.Document;


//import std.format;
import std.meta : AliasSeq, Filter;
import std.traits : isBasicType, isSomeString, isNumeric, getUDAs, EnumMembers, Unqual, ForeachType, isIntegral;
import std.conv : to, emplace;
import std.algorithm.iteration : map;
import std.algorithm.searching : count;
import std.range.primitives : walkLength;
import std.typecons : TypedefType;

//import std.stdio;

import tagion.utils.StdTime;
import tagion.basic.Basic : isOneOf;
import tagion.basic.Message : message;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONException;
import LEB128=tagion.utils.LEB128;
//import tagion.utils.LEB128 : isIntegral=isLEB128Integral;

//alias u32=LEB128.decode!uint;

// @safe uint u32(const(ubyte[]) data) pure {
//     size_t result;
//     LEB128.decode!uint(data, result);
//     return cast(result;
// }

//import std.stdio;
import std.exception;

static assert(uint.sizeof == 4);

/**
   Document is a lazy handler of HiBON serialized buffer
*/
@safe struct Document {
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
     This function returns the HiBON version
     Returns:
     HiBON version
     +/
    uint ver() const pure {
        if (data.length > ubyte.sizeof) {
            if (data[ubyte.sizeof] == Type.VER) {
                const leb128_version=LEB128.decode!uint(data[ubyte.sizeof..$]);
                return leb128_version.value;
            }
        }
        return 0;
    }
    /++
     Makes a copy of $(PARAM doc)
     Returns:
     Document copy
     +/
    @trusted
    void copy(ref const Document doc) {
        emplace(&this, doc);
    }

    @property const pure {
        @safe bool empty() nothrow {
            return data.length < 1;
        }

        @trusted uint size() {
            return LEB128.decode!uint(data).value;
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
    @safe
    struct Range {
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

        @property pure nothrow const {
            bool empty() {
                return _index > data.length;
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
            if (_index >= data.length) {
                _index = data.length+1;
            }
            else {
                emplace!Element(&_element, data[_index..$]);
                _index += _element.size;
            }
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
        return map!"a.index"(this[]);
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
            else if (element.key > key) {
                break;
            }
        }
        return Element();
    }

    const(Element) opBinaryRight(string op, Index)(const Index key) const if ((op == "in") && (isIntegral!Index)) {
        foreach (ref element; this[]) {
            if (element.isIndex && (element.index == key)) {
                return element;
            }
            else if (element.key[0] > '9') {
                break;
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
        auto result=index in this;
        .check(!result.isEod, message("Member index %d not found", index));
        return result;
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
        uint index;
        if (is_index(key, index)) {
            return sizeKey(index);
        }
        return Type.sizeof + LEB128.calc_size(key.length) + key.length;
    }

    static size_t sizeKey(uint key) pure {
        return Type.sizeof +  ubyte.sizeof + LEB128.calc_size(key);
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
    static size_t sizeT(T, Key)(Type type, Key key, const(T) x) pure if (is(Key:const(char[])) || is(Key==uint)) {
        size_t size = sizeKey(key);
        static if ( is(T: U[], U) ) {
            const _size=x.length*U.sizeof;
            size += LEB128.calc_size(_size) + _size;
        }
        else static if(is(T : const Document)) {
            size += calc_size(x.data.length) + x.data.length;
        }
        else static if(is(T : const BigNumber)) {
            size += x.calc_size;
        }
        else static if (isDataBlock!T) {
            const _size=x.size;
            size += LEB128.calc_size(_size) + _size;
        }
        else {
            alias BaseT=TypedefType!T;
            static if (isIntegral!BaseT) {
                size += LEB128.calc_size(cast(BaseT)x);
            }
            else {
                size += BaseT.sizeof;
            }
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
    @trusted
    static void buildKey(Key)(
        ref ubyte[] buffer, Type type, Key key, ref size_t index) pure if (is(Key:const(char[])) || is(Key==uint)) {
        static if (is(Key:const(char[]))) {
            uint key_index;
            if (is_index(key, key_index)) {
                buildKey(buffer, type, key_index, index);
                return;
            }
        }
        buffer.binwrite(type, &index);

        static if (is(Key:const(char[]))) {
            buffer.array_write(LEB128.encode(key.length), index);
            buffer.array_write(key, index);
        }
        else {
            buffer.binwrite(ubyte.init, &index);
            const key_leb128=LEB128.encode(key);
            buffer.array_write(key_leb128, index);
        }
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
    @trusted
    static void build(T, Key)(
        ref ubyte[] buffer, Type type, Key key, const(T) x, ref size_t index) pure if (is(Key:const(char[])) || is(Key==uint)) {
        buildKey(buffer, type, key, index);
        alias BaseT=TypedefType!T;
        static if (is(T: U[], U) && (U.sizeof == ubyte.sizeof)) {
            immutable size=LEB128.encode(x.length);
            buffer.array_write(size, index);
            buffer.array_write(x, index);
        }
        else static if (is(T : const Document)) {
            buffer.array_write(x.data, index);
        }
        else static if (is(T : const BigNumber)) {
            buffer.array_write(x.serialize, index);
        }
        else static if (isDataBlock!T) {
            immutable data=x.serialize;
            immutable size=LEB128.encode(data.length);
            buffer.array_write(size, index);
            buffer.array_write(data, index);
        }
        else static if (isIntegral!BaseT) {
            buffer.array_write(LEB128.encode(cast(BaseT)x), index);
        }
        else {
            buffer.binwrite(x, &index);
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


                string key() {
                    return range.front.key;
                }

            }
        }
    }

    version(unittest) {
        import std.typecons : Tuple, isTuple;

        static private size_t make(R)(ref ubyte[] buffer, R range, size_t count=size_t.max) if (isTuple!R) {
            size_t temp_index;
            auto temp_buffer=buffer.dup;
            foreach(i, t; range) {
                if ( i is count ) {
                    break;
                }
                enum name = range.fieldNames[i];
                alias U = range.Types[i];
                enum  E = Value.asType!U;
                static if (name.length is 0) {
                    build(temp_buffer, E, cast(uint)i, t, temp_index);
                }
                else {
                    build(temp_buffer, E, name, t, temp_index);
                }
            }
            auto leb128_size_buffer=LEB128.encode(temp_index);
            size_t index;
            buffer.array_write(leb128_size_buffer, index);
            buffer.array_write(temp_buffer[0..temp_index], index);
            return index;
        }
    }

    unittest {
        import std.algorithm.sorting : isSorted;
        auto buffer=new ubyte[0x200];
        //import std.stdio;
        { // Test of null document
            const doc = Document(null);
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        { // Test of empty Document
            size_t index;
            buffer.binwrite(ubyte.init, &index);
            immutable data=buffer[0..index].idup;
            const doc = Document(data);
            assert(doc.length is 0);
            assert(doc[].empty);

        }

        alias Tabel = Tuple!(
            BigNumber, Type.BIGINT.stringof,
            bool,   Type.BOOLEAN.stringof,
            float,  Type.FLOAT32.stringof,
            double, Type.FLOAT64.stringof,
            int,    Type.INT32.stringof,
            long,   Type.INT64.stringof,
            sdt_t,  Type.TIME.stringof,
            uint,   Type.UINT32.stringof,
            ulong,  Type.UINT64.stringof,

            );

        Tabel test_tabel;
        test_tabel.FLOAT32 = 1.23;
        test_tabel.FLOAT64 = 1.23e200;
        test_tabel.INT32   = -42;
        test_tabel.INT64   = -0x0123_3456_789A_BCDF;
        test_tabel.UINT32   = 42;
        test_tabel.UINT64   = 0x0123_3456_789A_BCDF;
        test_tabel.BIGINT   = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");
        test_tabel.BOOLEAN  = true;
        test_tabel.TIME      = 1001;

        alias TabelArray = Tuple!(
            immutable(ubyte)[],  Type.BINARY.stringof,
            // Credential,          Type.CREDENTIAL.stringof,
            // CryptDoc,            Type.CRYPTDOC.stringof,
            DataBlock,             Type.HASHDOC.stringof,
            string,              Type.STRING.stringof,
            );

        TabelArray test_tabel_array;
        test_tabel_array.BINARY        = [1, 2, 3];
        test_tabel_array.STRING        = "Text";
        test_tabel_array.HASHDOC       = DataBlock(27, [3,4,5]);
        // test_tabel_array.CRYPTDOC      = CryptDoc(42, [6,7,8]);
        // test_tabel_array.CREDENTIAL    = Credential(117, [9,10,11]);

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
                assert(doc.keys.is_key_ordered);

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

                    static if(E !is Type.BIGINT && E !is Type.TIME) {
                        assert(e.isThat!isBasicType);
                    }
                }
            }

            { // Document which includes basic arrays and string
                index = make(buffer, test_tabel_array);
                immutable data = buffer[0..index].idup;
                const doc=Document(data);
                assert(doc.keys.is_key_ordered);

                foreach(i, t; test_tabel_array) {
                    enum name = test_tabel_array.fieldNames[i];
                    alias U   = test_tabel_array.Types[i];
                    const v = doc[name].get!U;

                    assert(v == test_tabel_array[i]);
                    import traits=std.traits; // : isArray;
                    const e = doc[name];
                }
            }

            { // Document which includes sub-documents
                auto buffer_subdoc=new ubyte[0x200];
                index = make(buffer_subdoc, test_tabel);
                immutable data_sub_doc = buffer_subdoc[0..index].idup;
                const sub_doc=Document(data_sub_doc);

                index = 0;

                enum size_guess=151;
                uint size;
                buffer.array_write(LEB128.encode(size_guess), index);
                const start_index=index;
                enum doc_name="KDOC";

                immutable index_before=index;
                build(buffer, Type.INT32, Type.INT32.stringof, int(42), index);
                immutable data_int32 = buffer[index_before..index].idup;

                build(buffer, Type.DOCUMENT, doc_name, sub_doc, index);
                build(buffer, Type.STRING, Type.STRING.stringof, "Text", index);

                size = cast(uint)(index - start_index);
                assert(size == size_guess);

                size_t dummy_index=0;
                buffer.array_write(LEB128.encode(size), dummy_index);

                immutable data = buffer[0..index].idup;
                const doc=Document(data);
                assert(doc.keys.is_key_ordered);

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
                enum size_guess=27;

                index = 0;
                uint size;
                buffer.array_write(LEB128.encode(size_guess), index);
                const start_index=index;

                //buffer.binwrite(uint.init, &index);
                auto texts=["Text1", "Text2", "Text3"];
                foreach(i, text; texts) {
                    build(buffer, Type.STRING, i.to!string, text, index);
                }
                //buffer.binwrite(Type.NONE, &index);
                size = cast(uint)(index - start_index);
                assert(size == size_guess);

                //size = cast(uint)(index - uint.sizeof);
                //buffer.binwrite(size, 0);
                size_t dummy_index=0;
                buffer.array_write(LEB128.encode(size), dummy_index);

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
 * HiBON Element representation
 */
    @safe struct Element {
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

        //enum KEY_POS = Type.sizeof + keyLen.sizeof;

        @property uint keyPos() const pure {
            if (isIndex) {
                return Type.sizeof+ubyte.sizeof;
            }
            return cast(uint)(Type.sizeof+LEB128.calc_size(data[Type.sizeof..$]));
        }

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
            @trusted const(Value*) value() {
                immutable value_pos=valuePos;
                with(Type)
                TypeCase:
                switch(type) {
                    static foreach(E; EnumMembers!Type) {
                        static if (isHiBONType(E)) {
                        case E:
                            static if (E is DOCUMENT) {
                                immutable len=LEB128.decode!uint(data[value_pos..$]);
                                return new Value(Document(data[value_pos..value_pos+len.size+len.value]));
                            }
                            else static if ((E is STRING) || (E is BINARY)) {
                                alias T = Value.TypeT!E;
                                alias U = ForeachType!T;
                                immutable binary_len=LEB128.decode!uint(data[value_pos..$]);
                                immutable buffer_pos=value_pos+binary_len.size;
                                immutable buffer=(cast(immutable(U)*)(data[buffer_pos..$].ptr))[0..binary_len.value];
                                return new Value(buffer);
                            }
                            else static if (E is BIGINT) {
                                auto big_leb128=BigNumber.decodeLEB128(data[value_pos..$]);
                                return new Value(big_leb128.value);
                            }
                            else static if (isDataBlock(E)) {
                                immutable binary_len=LEB128.decode!uint(data[value_pos..$]);
                                immutable buffer_pos=value_pos+binary_len.size;
                                immutable buffer=data[buffer_pos..buffer_pos+binary_len.value];
                                return new Value(DataBlock(buffer));
                            }
                            else {
                                if (isHiBONType(type)) {
                                    static if (E is TIME) {
                                        alias T=long;
                                    }
                                    else {
                                        alias T = Value.TypeT!E;
                                    }
                                    static if (isIntegral!T) {
                                        auto result=new Value(LEB128.decode!T(data[value_pos..$]).value);
                                        return result;
                                    }
                                    else {
                                        return cast(Value*)(data[valuePos..$].ptr);
                                    }
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
            auto by(Type E)() {
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
            T get(T)() const {
                enum E = Value.asType!T;
                import std.format;
                static assert(E !is Type.NONE, format("Unsupported type %s", T.stringof));
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
                .check(isIndex, message("Key '%s' is not an index", key));
                return LEB128.decode!uint(data[keyPos..$]).value;
            }

            /++
             Returns:
             true if element key is an index
             +/
            version(none)
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

            bool isIndex() {
                return data[Type.sizeof] is 0;
            }
        }

        @property const pure {
            /++
             Returns:
             the key length
             +/
            uint keyLen() {
                if (isIndex) {
                    return cast(uint)LEB128.calc_size(data[keyPos..$]);
                }
                return LEB128.decode!uint(data[Type.sizeof..$]).value;
            }

            /++
             Returns:
             the key
             +/
            string key() {
                if (isIndex) {
                    const index=LEB128.decode!uint(data[keyPos..$]).value;
                    return index.to!string;
                }
                return cast(string)data[keyPos..valuePos];
            }

            /++
             Returns:
             the position of the value inside the element buffer
             +/
            uint valuePos() {
                return keyPos+keyLen;
            }

            uint dataPos() {
                return valuePos + cast(uint)LEB128.calc_size(data[valuePos..$]);
            }

            uint dataSize() {
                size_t len;
                return LEB128.decode!uint(data[valuePos..$]).value;
            }

            /++
             Returns:
             the size of the element in bytes
             +/
            @trusted size_t size() {
                with(Type) {
                TypeCase:
                    switch(type) {
                        static foreach(E; EnumMembers!Type) {
                        case E:
                            static if (isHiBONType(E)) {
                                alias T = Value.TypeT!E;
                                static if (
                                    (E is STRING) || (E is DOCUMENT) ||
                                    (E is BINARY)) {
                                    return dataPos + dataSize;
                                }
                                else static if (isDataBlock(E)) {
                                    return dataPos + dataSize;
                                }
                                else static if (E is BIGINT) {
                                    return valuePos + BigNumber.calc_size(data[valuePos..$]);
                                }
                                else {
                                    static if (E is TIME) {
                                        alias BaseT=long;
                                    }
                                    else {
                                        alias BaseT=T;
                                    }
                                    static if (isIntegral!BaseT) {
                                        return valuePos + LEB128.calc_size(data[valuePos..$]);
                                    }
                                    else {
                                        return valuePos + BaseT.sizeof;
                                    }
                                }
                            }
                            else static if (isNative(E)) {
                                static if (E is NATIVE_DOCUMENT) {
                                    const doc = Document(data[valuePos..$]);
                                    return valuePos + dataSize + doc.size;
                                }
                            }
                            else static if ( E is Type.NONE ) {
                                goto default;
                            }
                            break TypeCase;
                        }
                    default:
                        import std.format;
                        throw new HiBONException(format("Bad HiBON type %s", type));
                        // empty
                    }
                }
                assert(0);
            }


            enum ErrorCode {
                NONE,           // No errors
                INVALID_NULL,   // Invalid null object
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
                enum MIN_ELEMENT_SIZE = Type.sizeof + ubyte.sizeof + char.sizeof + ubyte.sizeof;

                with(ErrorCode) {
                    if ( type is Type.DOCUMENT ) {
                        return DOCUMENT_TYPE;
                    }
                    if ( data.length < MIN_ELEMENT_SIZE ) {
                        if (data.length !is ubyte.sizeof) {
                            return TOO_SMALL;
                        }
                        else if (data[0] !is 0) {
                            return INVALID_NULL;
                        }
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
                    if (type is Type.BINARY) {
                        const leb128_size=LEB128.decode!ulong(data[valuePos..$]);
                        if (leb128_size.value > uint.max) {
                            return OVERFLOW;
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
