/**
 * HiBON Document
 *
 */
module tagion.hibon.Document;

//import std.format;
import std.meta : AliasSeq, Filter;
import std.traits : isBasicType, isSomeString, isNumeric, EnumMembers, Unqual, ForeachType,
    isIntegral, hasMember, isArrayT = isArray, isAssociativeArray, OriginalType, isCallable;
import std.conv : to, emplace;
import std.algorithm;
import std.range;
import std.array : join;
import std.typecons : TypedefType;
import core.exception : RangeError;

//import std.stdio;

import tagion.utils.StdTime;
import tagion.basic.basic : isOneOf, EnumContinuousSequency;
import tagion.basic.Message : message;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONException : check, HiBONException;
import tagion.hibon.HiBONRecord : TYPENAME, isHiBONRecord, isHiBONTypeArray;
import tagion.basic.Types : isTypedef;
import LEB128 = tagion.utils.LEB128;

//import tagion.utils.LEB128 : isIntegral=isLEB128Integral;

//import std.stdio;
import std.exception;

static assert(uint.sizeof == 4);

/**
   Document is a lazy handler of HiBON serialized buffer
*/
@safe struct Document {
    alias Value = ValueT!(false, void, Document); /// HiBON Document value type
    protected immutable(ubyte)[] _data;

    /++
     Gets the internal buffer
     Returns:
     The buffer of the HiBON document
     +/
    //    @nogc
    immutable(ubyte[]) data() const pure nothrow {
        if (_data.length) {
            return _data[0 .. full_size];
        }
        immutable(ubyte[]) empty_doc = [0];
        return empty_doc;
    }

    /++
     Creates a HiBON Document from a buffer
     +/
    @nogc this(immutable(ubyte[]) data) pure nothrow scope {
        this._data = data;
    }

    /++
     Creates a replicate of a Document from another Document
     The buffer reused not copied
     Params:
     doc is the Document which is replicated
     +/
    @nogc this(const Document doc) pure nothrow scope {
        this._data = doc._data;
    }

    import tagion.hibon.HiBON : HiBON;

    this(const HiBON hibon) {
        if (hibon) {
            this._data = hibon.serialize;
        }
    }

    bool hasHashKey() pure const nothrow {
        import tagion.hibon.HiBONRecord : HiBONPrefix;

        return !empty &&
            keys.front[0] is HiBONPrefix.HASH;
    }

    unittest {
        { // empty document has no hash-key
            const doc = Document();
            assert(!doc.hasHashKey);
        }
        auto h = new HiBON;
        { // Document without hash-key
            h["x"] = 17;
            assert(!Document(h).hasHashKey);
        }
        { // Document with hash-key
            h["#x"] = 42;
            assert(Document(h).hasHashKey);
        }
    }

    /++
     This function returns the HiBON version
     Returns:
     HiBON version
     +/
    uint ver() const pure {
        if (data.length > ubyte.sizeof) {
            if (data[ubyte.sizeof] == Type.VER) {
                const leb128_version = LEB128.decode!uint(data[ubyte.sizeof .. $]);
                return leb128_version.value;
            }
        }
        return 0;
    }

    @property @nogc const pure nothrow {
        @safe bool empty() {
            return _data.length <= ubyte.sizeof;
        }

        uint size() {
            if (_data.length) {
                return LEB128.decode!uint(_data).value;
            }
            return 0;
        }

        size_t full_size() @nogc {
            if (_data.length) {
                const len = LEB128.decode!uint(_data);
                return len.size + len.value;
            }
            return 0;
        }

        size_t begin() @nogc {
            if (_data.length) {
                return LEB128.decode!uint(_data).size;
            }
            return 0;
        }
    }

    unittest { // Empty doc
    {
            const doc = Document();
            assert(doc._data.length is 0);
            assert(doc.data.length is 1);
            assert(doc.empty);
            assert(doc.size is 0);
            assert(doc.length is 0);
            auto range = doc[];
            assert(range.empty);
            range.popFront;
            assert(range.empty);
        }

        {
            immutable(ubyte[]) _data = [0];
            assert(_data.length is 1);
            const doc = Document(_data);
            assert(doc.data.length is 1);
            assert(doc.empty);
            assert(doc.size is 0);
            assert(doc.length is 0);
            assert(doc[].empty);
        }
    }

    unittest { // Document with residual data
        import tagion.hibon.HiBON;
        import std.algorithm.comparison : equal;

        auto h = new HiBON;
        h["test"] = 42;
        immutable(ubyte[]) residual = [42, 14, 217];
        immutable data = h.serialize ~ residual;
        const doc = Document(data);
        assert(doc.full_size == h.serialize.length);
        assert(doc.length == 1);
        assert(equal(doc.keys, ["test"]));

    }
    /++
     Counts the number of members in a Document
     Returns:
     Number of members in in the Document
     +/
    @property uint length() const pure {
        return cast(uint)(this[].walkLength);
    }

    /* 
	 * 
	 * Returns: true If both documents are the same
	 */
    bool opEquals(const Document rhs) const pure nothrow @nogc {
        return _data == rhs._data;
    }
    /++
     The deligate used by the valid function to report errors
     +/
    alias ErrorCallback = bool delegate(
            const Document main_doc,
            const Element.ErrorCode error_code,
            const(Element) current,
            const(Element) previous) nothrow @safe;

    /++
     This function check's if the Document is a valid HiBON format
     Params:
     If the delegate error_callback is the this function is call when a error occures
     Returns:
     Error code of the validation
     +/
    Element.ErrorCode valid(ErrorCallback error_callback = null) const nothrow {
        Element.ErrorCode inner_valid(const Document sub_doc,
                ErrorCallback error_callback = null) const nothrow {
            import tagion.basic.tagionexceptions : TagionException;

            auto previous = sub_doc[];
            bool not_first;
            Element.ErrorCode error_code;
            const doc_size = sub_doc.full_size; //LEB128.decode!uint(_data);
            if (doc_size > _data.length) {
                error_code = Element.ErrorCode.DOCUMENT_OVERFLOW;
                if (!error_callback || error_callback(this, error_code,
                        Element(), sub_doc.opSlice.front)) {
                    return error_code;
                }
            }
            foreach (ref e; sub_doc[]) {
                error_code = e.valid;
                if (not_first) {
                    if (e.data is previous.data) {
                        if (error_callback) {
                            error_callback(this, error_code, e, previous.front);
                            error_code = Element.ErrorCode.DOCUMENT_ITERATION;
                            error_callback(this, error_code,
                                    Document.Element(), Document.Element());
                        }
                        return error_code;
                    }
                    previous.popFront;
                }
                else {
                    not_first = true;
                }
                if (error_code is Element.ErrorCode.NONE) {
                    if (e.type is Type.DOCUMENT) {
                        try {
                            error_code = inner_valid(e.get!(Document), error_callback);
                        }
                        catch (HiBONException e) {
                            error_code = Element.ErrorCode.BAD_SUB_DOCUMENT;
                        }
                        catch (TagionException e) {
                            error_code = Element.ErrorCode.UNKNOW_TAGION;
                        }
                        catch (Exception e) {
                            error_code = Element.ErrorCode.UNKNOW;
                        }
                    }
                }
                if (error_code !is Element.ErrorCode.NONE) {
                    if (!error_callback || error_callback(this, error_code, e, previous.front)) {
                        return error_code;
                    }
                }
            }
            return Element.ErrorCode.NONE;
        }

        return inner_valid(this, error_callback);
    }

    /++
     Check if a Document format is the correct HiBON format.
     Uses the valid function
     Params:
     true if the Document is inorder
     +/
    // @trusted
    bool isInorder() const nothrow {
        return valid() is Element.ErrorCode.NONE;
    }

    /++
     Range of the Document
     +/
    @safe struct Range {
    @nogc:
        private immutable(ubyte)[] _data;
        immutable uint ver;
    public:
        this(immutable(ubyte[]) data) pure nothrow {
            if (data.length) {
                const _index = LEB128.calc_size(data);
                _data = data[_index .. $];
                uint _ver;
                if (!empty && (front.type is Type.VER)) {
                    const leb128_ver = LEB128.decode!uint(data);
                    _ver = leb128_ver.value;
                    _data = _data[leb128_ver.size .. $];
                }
                ver = _ver;
            }
        }

        this(const Document doc) pure nothrow {
            this(doc._data);
        }

        immutable(ubyte[]) data() const pure nothrow {
            return _data;
        }

        pure nothrow const {
            bool empty() {
                return _data.length is 0;
            }
            /**
             * InputRange primitive operation that returns the currently iterated element.
             */
            const(Element) front() {
                return Element(_data);
            }
        }

        /**
         * InputRange primitive operation that advances the range to its next element.
         */
        void popFront() pure nothrow {
            if (_data.length) {
                _data = _data[Element(_data).size .. $];
            }
        }
    }

    /++
     Returns:
     A range of Element's
     +/
    @nogc Range opSlice() const pure nothrow {
        if (full_size < _data.length) {
            return Range(_data[0 .. full_size]);
        }
        return Range(_data);
    }

    /++
     Returns:
     A range of the member keys in the document
     +/
    @nogc auto keys() const nothrow {
        return map!"a.key"(this[]);
    }

    /++
     The Document must only contain member names which represents an uint number
     Throws:
     an std.conv.ConvException if the keys can not be convert to an uint
     Returns:
     A range of indices of the type of uint in the Document
     +/
    auto indices() const pure {
        return map!"a.index"(this[]);
    }

    /++
     Check if the Document can be clasified as an Array
     Returns:
     Is true if all the keys in ordred numbers
     +/
    bool isArray() const nothrow pure {
        return .isArray(keys);
    }

    /++
     Returns:
     true if the key exist in the Document
     +/
    bool hasMember(scope string key) const pure nothrow {
        return !opBinaryRight!("in")(key).isEod();
    }

    /++
     Returns:
     true if the index exist in the Document
     +/
    bool hasMember(Index)(scope Index index) const if (isIntegral!Index) {
        return hasMember(index.to!string);
    }

    /++
     Find the element with key
     Returns:
     Returns the element with the key
     If on element with this key has been found an empty element is returned
     +/
    const(Element) opBinaryRight(string op)(in string key) const pure if (op == "in") {
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

    const(Element) opBinaryRight(string op, Index)(const Index key) const pure
    if ((op == "in") && (isIntegral!Index)) {
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
    const(Element) opIndex(in string key) const pure {
        auto result = key in this;

        

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
        auto result = index in this;
        check(!result.isEod, message("Member index %d not found", index));
        return result;
    }

    /++
     same as data
     +/
    alias serialize = data;

    /++
     Retruns:
     The number of bytes taken up by the key in the HiBON serialized stream
     +/
    @nogc static size_t sizeKey(const(char[]) key) pure nothrow {
        uint index;
        if (is_index(key, index)) {
            return sizeKey(index);
        }
        return Type.sizeof + LEB128.calc_size(key.length) + key.length;
    }

    @nogc static size_t sizeKey(uint key) pure nothrow {
        return Type.sizeof + ubyte.sizeof + LEB128.calc_size(key);
    }

    @nogc unittest {
        // Key is an index
        assert(sizeKey("0") is 3);
        assert(sizeKey("1000") is 4);
        // Key is a labelw
        assert(sizeKey("01000") is 7);
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
    @nogc static size_t sizeT(T, Key)(Type type, Key key, const(T) x) pure
    if (is(Key : const(char[])) || is(Key == uint)) {
        size_t size = sizeKey(key);
        static if (is(T : U[], U)) {
            const _size = x.length * U.sizeof;
            size += LEB128.calc_size(_size) + _size;
        }
        else static if (is(T : const Document)) {
            size += calc_size(x.data.length) + x.data.length;
        }
        else static if (is(T : const BigNumber)) {
            size += x.calc_size;
        }
        else {
            alias BaseT = TypedefType!T;
            static if (isIntegral!BaseT) {
                size += LEB128.calc_size(cast(BaseT) x);
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
    @trusted static void buildKey(Key)(ref ubyte[] buffer, Type type, Key key, ref size_t index) pure
    if (is(Key : const(char[])) || is(Key == uint)) {
        static if (is(Key : const(char[]))) {
            uint key_index;
            if (is_index(key, key_index)) {
                buildKey(buffer, type, key_index, index);
                return;
            }
        }
        buffer.binwrite(type, &index);

        static if (is(Key : const(char[]))) {
            buffer.array_write(LEB128.encode(key.length), index);
            buffer.array_write(key, index);
        }
        else {
            buffer.binwrite(ubyte.init, &index);
            const key_leb128 = LEB128.encode(key);
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
    @trusted static void build(T, Key)(ref ubyte[] buffer, Type type, Key key,
    const(T) x, ref size_t index) pure
    if (is(Key : const(char[])) || is(Key == uint)) {
        buildKey(buffer, type, key, index);
        alias BaseT = TypedefType!T;
        static if (is(T : U[], U) && (U.sizeof == ubyte.sizeof)) {
            immutable size = LEB128.encode(x.length);
            buffer.array_write(size, index);
            buffer.array_write(x, index);
        }
        else static if (is(T : const Document)) {
            buffer.array_write(x.data, index);
        }
        else static if (is(T : const BigNumber)) {
            buffer.array_write(x.serialize, index);
        }
        else static if (isIntegral!BaseT) {
            buffer.array_write(LEB128.encode(cast(BaseT) x), index);
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
    RangeT!U range(T : U[], U)() const pure {
        return RangeT!U(data);
    }

    @safe struct RangeT(T) {
        Range range;
        this(immutable(ubyte)[] data) pure {
            range = Range(data);
        }

        @property {
            void popFront() pure {
                range.popFront;
            }

            const(T) front() const {
                return range.front.get!T;
            }

            uint index() const {
                return range.front.index;
            }

            const pure {
                @nogc bool empty() nothrow {
                    return range.empty;
                }

                string key() {
                    return range.front.key;
                }

            }
        }
    }

    version (unittest) {
        import std.typecons : Tuple, isTuple;

        static private size_t make(R)(ref ubyte[] buffer, R range, size_t count = size_t.max) if (isTuple!R) {
            size_t temp_index;
            auto temp_buffer = buffer.dup;
            foreach (i, t; range) {
                if (i is count) {
                    break;
                }
                enum name = range.fieldNames[i];
                alias U = range.Types[i];
                enum E = Value.asType!U;
                static if (name.length is 0) {
                    build(temp_buffer, E, cast(uint) i, t, temp_index);
                }
                else {
                    build(temp_buffer, E, name, t, temp_index);
                }
            }
            auto leb128_size_buffer = LEB128.encode(temp_index);
            size_t index;
            buffer.array_write(leb128_size_buffer, index);
            buffer.array_write(temp_buffer[0 .. temp_index], index);
            return index;
        }
    }

    unittest {
        auto buffer = new ubyte[0x200];

        size_t index;
        @trusted size_t* index_ptr() {
            return &index;
        }

        //import std.stdio;
        { // Test of null document
            const doc = Document();
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        { // Test of empty Document

            buffer.binwrite(ubyte.init, index_ptr);
            immutable data = buffer[0 .. index].idup;
            const doc = Document(data);
            assert(doc.length is 0);
            assert(doc[].empty);

        }

        // dfmt off
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
        // dfmt on

        Tabel test_tabel;
        test_tabel.FLOAT32 = 1.23;
        test_tabel.FLOAT64 = 1.23e200;
        test_tabel.INT32 = -42;
        test_tabel.INT64 = -0x0123_3456_789A_BCDF;
        test_tabel.UINT32 = 42;
        test_tabel.UINT64 = 0x0123_3456_789A_BCDF;
        test_tabel.BIGINT = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");
        test_tabel.BOOLEAN = true;
        test_tabel.TIME = 1001;

        alias TabelArray = Tuple!(
                immutable(ubyte)[], Type.BINARY.stringof,
                string, Type.STRING.stringof,
        );

        TabelArray test_tabel_array;
        test_tabel_array.BINARY = [1, 2, 3];
        test_tabel_array.STRING = "Text";

        { // Document with simple types
            index = 0;

            { // Document with a single value
                index = make(buffer, test_tabel, 1);
                immutable data = buffer[0 .. index].idup;
                const doc = Document(data);
                assert(doc.length is 1);
                // assert(doc[Type.FLOAT32.stringof].get!float == test_tabel[0]);
            }

            { // Document including basic types
                index = make(buffer, test_tabel);
                immutable data = buffer[0 .. index].idup;
                const doc = Document(data);
                assert(doc.keys.is_key_ordered);

                auto keys = doc.keys;
                foreach (i, t; test_tabel) {
                    enum name = test_tabel.fieldNames[i];
                    alias U = test_tabel.Types[i];
                    enum E = Value.asType!U;
                    assert(doc.hasMember(name));
                    const e = doc[name];
                    assert(e.get!U == test_tabel[i]);
                    assert(keys.front == name);
                    keys.popFront;

                    auto e_in = name in doc;
                    assert(e.get!U == test_tabel[i]);

                    assert(e.type is E);
                    assert(e.isType!U);

                    static if (E !is Type.BIGINT && E !is Type.TIME) {
                        assert(e.isThat!isBasicType);
                    }
                }
            }

            { // Document which includes basic arrays and string
                index = make(buffer, test_tabel_array);
                immutable data = buffer[0 .. index].idup;
                const doc = Document(data);
                assert(doc.keys.is_key_ordered);

                foreach (i, t; test_tabel_array) {
                    enum name = test_tabel_array.fieldNames[i];
                    alias U = test_tabel_array.Types[i];
                    const v = doc[name].get!U;

                    assert(v == test_tabel_array[i]);
                    import traits = std.traits; // : isArray;
                    const e = doc[name];
                }
            }

            { // Document which includes sub-documents
                auto buffer_subdoc = new ubyte[0x200];
                index = make(buffer_subdoc, test_tabel);
                immutable data_sub_doc = buffer_subdoc[0 .. index].idup;
                const sub_doc = Document(data_sub_doc);

                index = 0;

                enum size_guess = 151;
                uint size;
                buffer.array_write(LEB128.encode(size_guess), index);
                const start_index = index;
                enum doc_name = "KDOC";

                immutable index_before = index;
                build(buffer, Type.INT32, Type.INT32.stringof, int(42), index);
                immutable data_int32 = buffer[index_before .. index].idup;

                build(buffer, Type.DOCUMENT, doc_name, sub_doc, index);
                build(buffer, Type.STRING, Type.STRING.stringof, "Text", index);

                size = cast(uint)(index - start_index);
                assert(size == size_guess);

                size_t dummy_index = 0;
                buffer.array_write(LEB128.encode(size), dummy_index);

                immutable data = buffer[0 .. index].idup;
                const doc = Document(data);
                assert(doc.keys.is_key_ordered);

                { // Check int32 in doc
                    const int32_e = doc[Type.INT32.stringof];
                    assert(int32_e.type is Type.INT32);
                    assert(int32_e.get!int  is int(42));
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
                    assert(
                            under_e.size == data_sub_doc.length + Type.sizeof
                            + ubyte.sizeof + doc_name.length);

                    const under_doc = doc[doc_name].get!Document;
                    assert(under_doc.data.length == data_sub_doc.length);

                    auto keys = under_doc.keys;
                    foreach (i, t; test_tabel) {
                        enum name = test_tabel.fieldNames[i];
                        alias U = test_tabel.Types[i];
                        enum E = Value.asType!U;
                        assert(under_doc.hasMember(name));
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
                enum size_guess = 27;

                index = 0;
                uint size;
                buffer.array_write(LEB128.encode(size_guess), index);
                const start_index = index;

                //buffer.binwrite(uint.init, &index);
                auto texts = ["Text1", "Text2", "Text3"];
                foreach (i, text; texts) {
                    build(buffer, Type.STRING, i.to!string, text, index);
                }
                //buffer.binwrite(Type.NONE, &index);
                size = cast(uint)(index - start_index);
                assert(size == size_guess);

                //size = cast(uint)(index - uint.sizeof);
                //buffer.binwrite(size, 0);
                size_t dummy_index = 0;
                buffer.array_write(LEB128.encode(size), dummy_index);

                immutable data = buffer[0 .. index].idup;
                const doc = Document(data);

                auto typed_range = doc.range!(string[])();
                foreach (i, text; texts) {
                    assert(!typed_range.empty);
                    assert(typed_range.key == i.to!string);
                    assert(typed_range.index == i);
                    assert(typed_range.front == text);
                    typed_range.popFront;
                }
            }
        }
    }

    enum isDocTypedef(T) = isTypedef!T && !is(T == sdt_t);

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
        @nogc this(immutable(ubyte[]) data) pure nothrow {
            // In this time, Element does not parse a binary data.
            // This is lazy initialization for some efficient.
            this.data = data;
        }

        /++
         Returns:
         The HiBON Value of the element
         throws:
         if  the type is invalid and HiBONException is thrown
         +/
        @property @trusted const(Value*) value() const pure {
            immutable value_pos = valuePos;
            with (Type)
        TypeCase : switch (type) {
                static foreach (E; EnumMembers!Type) {
                    static if (isHiBONBaseType(E)) {
            case E:
                        static if (E is DOCUMENT) {
                            immutable len = LEB128.decode!uint(data[value_pos .. $]);
                            return new Value(Document(
                                    data[value_pos .. value_pos + len.size + len.value]));
                        }
                        else static if ((E is STRING) || (E is BINARY)) {
                            alias T = Value.TypeT!E;
                            alias U = ForeachType!T;
                            immutable binary_len = LEB128.decode!uint(data[value_pos .. $]);
                            immutable buffer_pos = value_pos + binary_len.size;
                            immutable buffer = (cast(immutable(U)*)(data[buffer_pos .. $].ptr))[0
                                .. binary_len.value];
                            return new Value(buffer);
                        }
                        else static if (E is BIGINT) {
                            auto big_leb128 = BigNumber.decodeLEB128(data[value_pos .. $]);
                            return new Value(big_leb128.value);
                        }
                        else {
                            if (isHiBONBaseType(type)) {
                                static if (E is TIME) {
                                    alias T = long;
                                }
                                else {
                                    alias T = Value.TypeT!E;
                                }
                                static if (isIntegral!T) {
                                    auto result = new Value(LEB128.decode!T(data[value_pos .. $])
                                        .value);
                                    return result;
                                }
                                else {
                                    return cast(Value*)(data[value_pos .. $].ptr);
                                }
                            }
                            break TypeCase;

                        }
                    }
                }
            default:
                //empty
            }

            

            .check(0, message("Invalid type %s", type));
            assert(0);
        }

        @property const {
            /++
             Returns:
             the value as the HiBON type Type
             throws:
             if the element does not contain the type E and HiBONException is thrown
             +/
            auto by(Type E)() pure {

                

                    .check(type is E,
                            message("Type expected is %s but the actual type is %s", E, type));

                

                .check(E !is Type.NONE,
                        message("Type is not supported %s the actual type is %s", E, type));
                return value.by!E;
            }

            /++
             Returns:
             the value as the type T
             throws:
             if the element does not contain the type and HiBONException is thrown
             +/
            T get(T)() if (isHiBONRecord!T) {
                const doc = get!Document;
                return T(doc);
            }

            T get(T)() if (isDocTypedef!T) {
                alias BaseType = TypedefBase!T;
                const ret = get!BaseType;
                return T(ret);
            }

            static unittest {
                import std.typecons : Typedef;

                alias BUF = immutable(ubyte)[];
                alias Tdef = Typedef!(BUF, null, "SPECIAL");
                static assert(is(typeof(get!Tdef) == Tdef));
            }

            @trusted T get(T)() if (isHiBONTypeArray!T) {
                alias ElementT = ForeachType!T;
                const doc = get!Document;
                alias UnqualT = Unqual!T;
                UnqualT result;
                static if (isAssociativeArray!T) {
                    foreach (e; doc[]) {
                        result[e.key] = e.get!ElementT;
                    }
                }
                else {

                    

                        .check(doc.isArray, "Document must be an array");
                    result.length = doc.length;
                    foreach (ref a, e; lockstep(result, doc[])) {
                        a = e.get!ElementT;
                    }
                }
                return cast(T) result;
            }

            T get(T)() const if (is(T == enum)) {
                alias EnumBaseT = OriginalType!T;
                const x = get!EnumBaseT;
                static if (EnumContinuousSequency!T) {
                    check((x >= T.min) && (x <= T.max),
                            message("The value %s is out side the range for %s enum type",
                            x, T.stringof));
                }
                else {
                EnumCase:
                    switch (x) {
                        static foreach (E; EnumMembers!T) {
                    case E:
                            break EnumCase;
                        }
                    default:
                        check(0, message("The value %s does not fit into the %s enum type",
                                x, T.stringof));
                    }
                }
                return cast(T) x;
            }

            T get(T)() const
            if (!isHiBONRecord!T && !isHiBONTypeArray!T && !is(T == enum) && !isDocTypedef!T) {
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
            bool as(T)(ref T result) pure nothrow {
                switch (type) {
                    static foreach (E; EnumMembers!Type) {
                        static if (isHiBONBaseType(E)) {
                case E:
                            alias BaseT = Value.TypeT!E;
                            static if (isImplicitlyConvertible!(BaseT, T)) {
                                result = value.get!BaseT;
                                return true;
                            }
                            else static if (__traits(compiles, value.get!(BaseT).to!T)) {
                                result = value.get!(BaseT)
                                    .to!T;
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
            uint index() pure {

                

                    .check(isIndex, [
                    "Key '", key.to!string, "' is not an index", key
                ].join);
                return LEB128.decode!uint(data[keyPos .. $]).value;
            }

        }

        @property @nogc const pure nothrow {
            /++
             Retruns:
             true if the elemnt is of T
             +/
            bool isType(T)() {
                enum E = Value.asType!T;
                return (E !is Type.NONE) && (type is E);
            }

            uint keyPos() {
                if (isIndex) {
                    return Type.sizeof + ubyte.sizeof;
                }
                return cast(uint)(Type.sizeof + LEB128.calc_size(data[Type.sizeof .. $]));
            }

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
             true if element key is an index
             +/
            bool isIndex() {
                return data[Type.sizeof] is 0;
            }

        }

        /++
         Returns:
         true if the type and the value of the element is equal to rhs
         +/
        bool opEquals(T)(auto ref const T rhs) const pure nothrow if (!is(T : const(Element))) {
            enum rhs_type = Value.asType!T;
            return (rhs_type is type) && (assumeWontThrow(by!rhs_type) == rhs);
        }

        unittest { // Test if opEquals can handle types
            auto h = new HiBON;
            h["number"] = 42;
            h["text"] = "42";
            const doc = Document(h);
            assert(doc["number"] == 42);
            assert(doc["number"] != "42");
            assert(doc["text"] != 42);
            assert(doc["text"] == "42");
        }

        @property @nogc const pure nothrow {
            /++
             Returns:
             the key length
             +/
            uint keyLen() {
                if (isIndex) {
                    return cast(uint) LEB128.calc_size(data[keyPos .. $]);
                }
                return LEB128.decode!uint(data[Type.sizeof .. $]).value;
            }

            /++
             Returns:
             the position of the value inside the element buffer
             +/
            uint valuePos() {
                return keyPos + keyLen;
            }

            uint dataPos() {
                return valuePos + cast(uint) LEB128.calc_size(data[valuePos .. $]);
            }

            uint dataSize() {
                return LEB128.decode!uint(data[valuePos .. $]).value;
            }

            /++
             Check if the type match That template.
             That template must have one parameter T as followes
             Returns:
             true if the element is the type That
             +/

            bool isThat(alias That)() {
            TypeCase:
                switch (type) {
                    static foreach (E; EnumMembers!Type) {
                case E:
                        static if (isHiBONBaseType(E)) {
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
            /++
             Returns:
             the size of the element in bytes
             On error it returns size 0
             +/
            @trusted size_t size() {
                with (Type) {
                TypeCase:
                    switch (type) {
                        static foreach (E; EnumMembers!Type) {
                    case E:
                            static if (isHiBONBaseType(E)) {
                                alias T = Value.TypeT!E;
                                static if ((E is STRING) || (E is DOCUMENT) || (E is BINARY)) {
                                    return dataPos + dataSize;
                                }
                                else static if (E is BIGINT) {
                                    return valuePos + BigNumber.calc_size(data[valuePos .. $]);
                                }
                                else {
                                    static if (E is TIME) {
                                        alias BaseT = long;
                                    }
                                    else {
                                        alias BaseT = T;
                                    }
                                    static if (isIntegral!BaseT) {
                                        return valuePos + LEB128.calc_size(data[valuePos .. $]);
                                    }
                                    else {
                                        return valuePos + BaseT.sizeof;
                                    }
                                }
                            }
                            else static if (isNative(E)) {
                                static if (E is NATIVE_DOCUMENT) {
                                    const doc = Document(data[valuePos .. $]);
                                    return valuePos + dataSize + doc.size;
                                }
                            }
                            else static if (E is Type.NONE) {
                                goto default;
                            }
                            break TypeCase;
                        }
                    default:
                        return 0;
                    }
                }
                return 0;
                //                assert(0);
            }

            /++
             Compare two elements
             +/
            bool opEquals(ref const Element other) {
                immutable s = size;
                if (s !is other.size) {
                    return false;
                }
                return data[0 .. s] == other.data[0 .. s];
            }

            enum ErrorCode {
                NONE, /// No errors
                INVALID_NULL, /// Invalid null object
                //DOCUMENT_TYPE,  /// Warning document type
                DOCUMENT_OVERFLOW, /// Document length extends the length of the buffer
                DOCUMENT_ITERATION, /// Document can not be iterated because of a Document format fail
                VALUE_POS_OVERFLOW, /// Start position of the a value extends the length of the buffer
                TOO_SMALL, /// Data stream is too small to contain valid data
                ILLEGAL_TYPE, /// Use of internal types is illegal
                INVALID_TYPE, /// Type is not defined
                OVERFLOW, /// The specifed data does not fit into the data stream
                ARRAY_SIZE_BAD, /// The binary-array size in bytes is not a multipla of element size in the array
                KEY_ORDER, /// Error in the key order
                KEY_NOT_DEFINED, /// Key in the target was not defined
                KEY_INVALID, /// Key is not a valid string
                //                KEY_SIZE_OVERFLOW, /// Key size overflow (Key size extents beyond the data buffer
                KEY_POS_OVERFLOW, /// The start
                BAD_SUB_DOCUMENT, /// Error convering sub document
                NOT_AN_ARRAY, /// Not an Document array
                KEY_ZERO_SIZE, /// Invalid zero key size
                RESERVED_KEY, /// Name of the key is reserved 
                RESERVED_HIBON_TYPE, /// HiBON type name is reserved for internal use
                UNKNOW_TAGION, /// Unknow error (used when some underlaying function thows an TagionException
                UNKNOW /// Unknow error (used when some underlaying function thows an Exception

            }

        }
        /++
         Check if the element is valid
         Returns:
         The error code the element.
         ErrorCode.NONE means that the element is valid

         +/
        @trusted ErrorCode valid() const pure nothrow {
            enum MIN_ELEMENT_SIZE = Type.sizeof + ubyte.sizeof + char.sizeof + ubyte.sizeof;

            with (ErrorCode) {
                // if ( type is Type.DOCUMENT ) {
                //     return DOCUMENT_TYPE;
                // }
                if (data.length < MIN_ELEMENT_SIZE) {
                    if (data.length !is ubyte.sizeof) {
                        return TOO_SMALL;
                    }
                    else if (data[0]!is 0) {
                        return INVALID_NULL;
                    }
                }
                if (keyPos >= data.length) {
                    return KEY_POS_OVERFLOW;
                }
                if (valuePos >= data.length) {
                    return VALUE_POS_OVERFLOW;
                }
                if (key.length is 0) {
                    return KEY_ZERO_SIZE;
                }
                // if (key.length >= data.length) {
                //     return KEY_SIZE_OVERFLOW;
                // }
                if (!key.is_key_valid) {
                    return KEY_INVALID;
                }

                if ((isNative(type) || (type is Type.DEFINED_ARRAY))) {
                    return ILLEGAL_TYPE;
                }
                if (size > data.length) {
                    return OVERFLOW;
                }
                if (type is Type.BINARY) {
                    const leb128_size = LEB128.decode!ulong(data[valuePos .. $]);
                    if (leb128_size.value > uint.max) {
                        return OVERFLOW;
                    }
                }
                if (!isValidType(type)) {
                    return INVALID_TYPE;
                }
                if (key[0 .. min(TYPENAME.length, $)] == TYPENAME) {
                    if (key.length != TYPENAME.length) {
                        return RESERVED_KEY;
                    }
                    if (type is Type.STRING) {
                        const len = LEB128.decode!uint(data[valuePos .. $]);
                        const type_name = data[valuePos + len.size .. valuePos + len.size + len.value];
                        if (type_name.length >= TYPENAME.length &&
                                type_name[0 .. TYPENAME.length] == TYPENAME) {
                            return RESERVED_HIBON_TYPE;
                        }
                    }
                }

                return NONE;
            }
        }

        @property const pure nothrow {

            /++
             Returns:
             the key
             +/
            string key() {
                if (isIndex) {
                    const index = LEB128.decode!uint(data[keyPos .. $]).value;
                    return index.to!string;
                }
                return cast(string) data[keyPos .. valuePos];
            }
        }

    }
}

@safe
unittest { // Bugfix (Fails in isInorder);
{
        immutable(ubyte[]) data = [
            220, 252, 73, 35, 27, 55, 228, 198, 34, 5, 5, 13, 153, 209, 212,
            161, 82, 232, 239, 91, 103, 93, 26, 163, 205, 99, 121, 104, 172, 161,
            131, 175
        ];
        const doc = Document(data);
        assert(!doc.isInorder);
        assert(doc.valid is Document.Element.ErrorCode.DOCUMENT_OVERFLOW);
    }
}

@safe
unittest {

}
