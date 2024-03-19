//// \file Document.d

module tagion.betterC.hibon.Document;

@nogc:
//import std.format;
import std.algorithm.iteration : map;
import std.algorithm.searching : count;
import std.conv : emplace;
import std.meta : AliasSeq, Filter;
import std.traits : EnumMembers, ForeachType, Unqual, getUDAs, isBasicType, isIntegral, isNumeric, isSomeString;

//import core.stdc.stdio;
//import std.range.primitives : walkLength;

import tagion.betterC.hibon.HiBON;
import tagion.betterC.utils.Bailout;
import tagion.betterC.utils.BinBuffer;
import tagion.betterC.utils.Memory;
import tagion.betterC.utils.Text;
import tagion.betterC.utils.sdt;
import LEB128 = tagion.betterC.utils.LEB128;
import tagion.betterC.hibon.BigNumber;
import tagion.betterC.hibon.HiBONBase;

// import std.exception;

static assert(uint.sizeof == 4);

/**
 * @brief Document is a lazy handler of HiBON serialized buffer
 */

/**
 * Document is used for storage different data and provide
 * possibility to read and analyze data
 */
struct Document {
    // @nogc:
    /**
     * HiBON Document value type
     */
    alias Value = ValueT!(false, void, Document);

    /**
     * Actual data
     */
    protected immutable(ubyte)[] _data;

    /**
     * Gets the internal buffer
     * @return the buffer of the HiBON document
     */
    @nogc immutable(ubyte[]) data() const {
        if (_data.length) {
            ubyte[] result;
            result.create(full_size);
            foreach (i, elem; _data) {
                result[i] = elem;
            }
            return cast(immutable)(result);
        }
        ubyte[] empty_doc;
        empty_doc.create(1);

        return cast(immutable)(empty_doc);
    }

    /**
      * Creates a HiBON Document from a buffer
      * @param data - buffer
      */
    @nogc this(immutable(ubyte[]) data) pure {
        this._data = data;
    }

    /**
     * Creates a replicate of a Document from another Document
     * The buffer reused not copied
     * @param doc - Document which is replicated
     */
    @nogc this(const Document doc) pure {
        this._data = doc._data;
    }

    /**
     * Creates a document which is based on HiBON
     * @param hibon - reference to the HiBON object
     */
    this(HiBONT hibon) {
        //check hibon
        this._data = hibon.serialize;
    }

    this(const HiBONT hibon) {
        //check hibon
        auto mut_hibon = cast(HiBONT) hibon;
        this._data = mut_hibon.serialize;
    }

    /**
     * Returns HiBON version
     * @return HiBON version
     */
    uint ver() const {
        if (data.length > ubyte.sizeof) {
            if (data[ubyte.sizeof] == Type.VER) {
                const leb128_version = LEB128.decode!uint(data[ubyte.sizeof .. $]);
                return leb128_version.value;
            }
        }
        return 0;
    }

    void surrender() pure {
        _data = null;
    }

    /**
     * Makes a cope od document
     * @rapam doc - Document that will be copied
     */
    void copy(ref const Document doc) {
        emplace(&this, doc);
    }

    @property const {
        @trusted bool empty() {
            return data.length <= ubyte.sizeof;
        }

        @nogc uint size() {
            return LEB128.decode!uint(data).value;
        }

        @nogc size_t full_size() {
            if (_data.length) {
                const len = LEB128.decode!uint(_data);
                return len.size + len.value;
            }
            return 0;
        }
    }

    unittest { // Empty doc
    {
            Document doc;
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

    // unittest { // Document with residual data
    //     import tagion.betterC.hibon.HiBON;

    //     // import std.algorithm.comparison : equal;
    //     auto h = HiBON();
    //     h["test"] = 42;
    //     immutable(ubyte[3]) residual = [42, 14, 217];
    //     immutable data = h.serialize ~ residual;
    //     const doc = Document(data);
    //     assert(doc.full_size == h.serialize.length);
    //     assert(doc.length == 1);
    // }

    /**
     * Counts the number of members in a Document
     * @return number of members in in the Document
     */
    @nogc @property uint length() const {
        uint count;
        foreach (e; this[]) {
            count++;
        }
        return count;
    }

    /**
     * The deligate used by the valid function to report errors
     */
    alias ErrorCallback = void delegate(scope const(Element) current,
            scope const(Element) previous);

    /**
     * Function check's if the Document is a valid HiBON format
     * @param error_callback - if the delegate error_callback is the this function is call when a error occurs
     * @return error code of the validation
     */
    Element.ErrorCode valid(ErrorCallback error_callback = null) const {
        auto previous = this[];
        bool not_first;
        foreach (ref e; this[]) {
            Element.ErrorCode error_code;
            Text work_key;
            Text previous_work_key;
            if (not_first && (key_compare(previous.front.key(previous_work_key), e.key(work_key)) >= 0)) {
                error_code = Element.ErrorCode.KEY_ORDER;
            }
            else if (e.type is Type.DOCUMENT) {
                error_code = e.get!(Document).valid(error_callback);
            }
            else {
                error_code = e.valid;
            }
            if (error_code !is Element.ErrorCode.NONE) {
                if (error_callback) {
                    error_callback(e, previous.front);
                }
                return error_code;
            }
            if (not_first) {
                previous.popFront;
            }
            not_first = true;
        }
        return Element.ErrorCode.NONE;
    }

    /**
     * Check if a Document format is the correct HiBON format.
     * Uses the valid function
     * @return true if the Document is inorder
     */
    bool isInorder() const {
        return valid() is Element.ErrorCode.NONE;
    }

    /**
     * Range of the Document
     */
    struct Range {
    @nogc:
        /**
         * Buffer with data
         */
        immutable(ubyte)[] data;

        /**
         * Version
         */
        immutable uint ver;
    protected:
        /**
         * Range size
         */
        size_t _index;

        /**
         * HiBON Element
         */
        Element _element;

    public:
        @disable this();
        /**
         * Construct Range based on buffer
         * @param data - buffer of data
         */
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
                    const leb128_ver = LEB128.decode!uint(data[_index .. $]);
                    _ver = leb128_ver.value;
                    _index += leb128_ver.size;
                }
                ver = _ver;
            }
        }

        /**
         * Construct Range based on other Document
         * @param doc - Document
         */
        this(const Document doc) {
            this(doc.data);
        }

        @property pure const {
            /**
             * Checks is Range empty
             * @return true if data length = 0
             */
            bool empty() {
                return data.length is 0;
            }

            /**
             * InputRange primitive operation
             * @return currently iterated element
             */
        }
        const(Element) front() {
            return Element(data);
        }

        /**
         * InputRange primitive operation that advances the range to its next element.
         */
        void popFront() {
            if (data.length) {
                data = data[Element(data).size .. $];
            }
        }
    }

    /**
     * @return range of Element's
     */
    @nogc Range opSlice() const {
        if (full_size < _data.length) {
            return Range(_data[0 .. full_size]);
        }
        return Range(_data);
    }

    /**
     * @return range of the member keys in the document
     */
    KeyRange keys() const {
        return KeyRange(_data);
    }

    protected struct KeyRange {
    @nogc:
        Text work_key;
        Range range;
        this(immutable(ubyte[]) data) {
            range = Range(data);
        }

        @property bool empty() const pure {
            return range.empty;
        }

        @property void popFront() {
            range.popFront;
        }

        string front() {
            return range.front.key(work_key);
        }

        ~this() {
            work_key.dispose;
        }
    }

    /**
     * The Document must only contain member names which represents an uint number
     * Throws an std.conv.ConvException if the keys can not be convert to an uint
     * @return range of indices of the type of uint in the Document
    */
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
            range = Range(data);
        }

        @property bool empty() const pure {
            return range.empty;
        }

        uint front() {
            Text work_key;
            const key = range.front.key(work_key);
            uint index;
            if (!is_index(key, index)) {
                _error = true;
            }
            return index;
        }

        @property void popFront() {
            range.popFront;
        }

        @property error() const pure {
            return _error;
        }
    }

    /**
     * Check if the Document can be classified as an Array
     * @return true if all the keys in ordred numbers
     */
    bool isArray() const {
        auto range = indices;
        while (!range.empty) {
            range.popFront;
            if (range.error) {
                return false;
            }
        }
        return true;
    }

    /**
     * @return true if the key exist in the Document
     */
    @trusted bool hasMember(scope string key) const {
        return !opBinaryRight!("in")(key).isEod();
    }

    /**
     * @return true if the index exist in the Document
     */
    @trusted bool hasMember(Index)(scope Index index) const if (isIntegral!Index) {
        return hasMember(index.to!string);
    }

    /**
     * Find the element with key
     * @return the element with the key, if on element with this key has been found an empty element is returned
     */
    const(Element) opBinaryRight(string op)(in string key) const if (op == "in") {
        foreach (element; this[]) {
            Text work_key;
            if (element.key(work_key).length == key.length) {
                bool isEqual = true;
                for (int i = 0; i < key.length; i++) {
                    if (element.key(work_key)[i] != key[i]) {
                        isEqual = false;
                        break;
                    }
                }
                if (isEqual) {
                    return element;
                }
            }
            if (element.key(work_key) > key) {
                break;
            }
        }
        return Element();
    }

    const(Element) opBinaryRight(string op, Index)(const Index key) const
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

    /**
     * @return the element with the key
     * @throw if the element with the key is not found then and HiBONException is thrown
     */
    @trusted @nogc const(Element) opIndex(in string key) const {
        auto result = key in this;
        return result;
    }

    /**
     * @return the element with the index
     * @throw if the element with the key is not found then and HiBONException is thrown
       Or of the key is not an index a std.conv.ConvException is thrown
     */
    @trusted @nogc const(Element) opIndex(Index)(in Index index) const
    if (isIntegral!Index) {
        import tagion.betterC.utils.StringHelper;

        auto index_string = int_to_str(index);
        scope (exit) {
            index_string.dispose;
        }

        return opIndex(index_string);
    }

    /**
     * Same as data
     */
    alias serialize = data;

    /**
     * @param key, which size needs to be calculated
     * @return the number of bytes taken up by the key in the HiBON serialized stream
     */
    @nogc static size_t sizeKey(const(char[]) key) pure {
        uint index;
        if (is_index(key, index)) {
            return sizeKey(index);
        }
        return Type.sizeof + LEB128.calc_size(key.length) + key.length;
    }

    /**
     * @param key, which size needs to be calculated
     * @return the number of bytes taken up by the key in the HiBON serialized stream
     */
    @nogc static size_t sizeKey(uint key) pure {
        return Type.sizeof + ubyte.sizeof + LEB128.calc_size(key);
    }

    unittest {
        // Key is an index
        assert(sizeKey("0") is 3);
        assert(sizeKey("1000") is 4);
        // Key is a labelw
        assert(sizeKey("01000") is 7);
    }

    /**
     * Calculates the number of bytes taken up by an element in the HiBON serialized stream
     * @param type = is the HIBON type
     * @param key = is the key name
     * @param x = is the value
     * @return the number of bytes taken up by the element
     */
    @nogc static size_t sizeT(T, K)(Type type, K key, const(T) x) {
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
        else static if (isDataBlock!T) {
            const _size = x.size;
            size += LEB128.calc_size(_size) + _size;
        }
        else {
            //alias BaseT=TypedefType!T;
            static if (isIntegral!T) {
                size += LEB128.calc_size(x);
            }
            else {
                size += T.sizeof;
            }
        }
        return size;
    }

    /**
     * Append the key to the buffer
     * @param buffer = is the target buffer
     * @param type = is the HiBON type
     * @param key = is the member key
     * @param index = is offset index in side the buffer and index with be progressed
     */
    static void buildKey(K)(
            ref BinBuffer buffer, Type type, const K key) if (is(K : const(char[])) || is(K == uint)) {
        static if (is(K : const(char[]))) {
            uint key_index;
            if (is_index(key, key_index)) {
                buildKey(buffer, type, key_index);
                return;
            }
        }
        buffer.write(type);
        static if (is(K : const(char[]))) {
            LEB128.encode(buffer, key.length);
            buffer.write(key);
        }
        else {
            buffer.write(ubyte(0));
            LEB128.encode(buffer, key);
        }
    }

    /**
     * Append a full element to a buffer
     * @param buffer = is the target buffer
     * @param type = is the HiBON type
     * @param key = is the member key
     * @param x = is the value of the element
     * @param index = is offset index in side the buffer and index with be progressed
     */
    static void build(T, K)(ref BinBuffer buffer, Type type, const K key, const(T) x)
            if (is(K : const(char[])) || is(K == uint)) {
        const build_size = buffer.length;
        buildKey(buffer, type, key);
        static if (is(T : U[], U)) {
            immutable size = cast(uint)(x.length * U.sizeof);
            LEB128.encode(buffer, size);
            buffer.write(x);
        }
        else static if (is(T : const Document)) {
            buffer.write(x.data);
        }
        else static if (is(T : const BigNumber)) {
            buffer.write(x.serialize);
        }
        else static if (is(T : const DataBlock)) {
            x.serialize(buffer);
        }
        else static if (is(T : const sdt_t)) {
            LEB128.encode(buffer, x.time);
        }
        else static if (isIntegral!T) {
            LEB128.encode(buffer, x);
        }
        else {
            buffer.write(x);
        }
    }

    /**
     * This range is used to generate and range of same type U
     * If the Document contains and Array of the elements this range can be used
     * @param Range (Array) of the type U
     */
    RangeT!U range(T : U[], U)() const {
        return RangeT!U(data);
    }

    struct RangeT(T) {
    @nogc:
        Range range;
        enum EType = Value.asType!T;
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

            const {
                bool empty() pure {
                    return range.empty;
                }

                string key(ref Text work_key) {
                    return range.front.key(work_key);
                }
            }
        }
    }

    version (unittest) {
        import std.typecons : Tuple, isTuple;
        import tagion.betterC.utils.Basic : basename;

        static private void make(R)(ref ubyte[] buffer, R range, size_t count = size_t.max) if (isTuple!R) {
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
        }
    }

    unittest {
        { // Test of null document
            const doc = Document(null);
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        { // Test of empty Document
            auto buffer = BinBuffer(0x200);
            size_t index;
            buffer.write(uint.init);
            buffer.write(Type.NONE);
            buffer.write(uint(1), 0);
            const doc_buffer = buffer[0 .. index];
            const doc = Document(doc_buffer.serialize);
            assert(doc.length is 0);
            assert(doc[].empty);

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
        /**
         * Construct an Element based on buffer
         * @param data - buffer
         */
        this(immutable(ubyte[]) data) {
            // In this time, Element does not parse a binary data.
            // This is lazy initialization for some efficient.
            this.data = data;
        }

        //enum KEY_POS = Type.sizeof + keyLen.sizeof;

        /**
         * Evaluates key position
         * @return key position
         */
        @property uint keyPos() const {
            if (isIndex) {
                return Type.sizeof + ubyte.sizeof;
            }
            return cast(uint)(Type.sizeof + LEB128.calc_size(data[Type.sizeof .. $]));
        }

        @property const {
            /**
             * @return true if the element is of T
             */
            bool isType(T)() {
                enum E = Value.asType!T;
                return (E !is Type.NONE) && (type is E);
            }

            /**
             * @return the HiBON Value of the element
             * @throw if  the type is invalid and HiBONException is thrown
             */
            const(Value) value() {
                immutable value_pos = valuePos;
                with (Type)
            TypeCase : switch (type) {
                    static foreach (E; EnumMembers!Type) {
                        static if (isHiBONBaseType(E)) {
                case E:
                            static if (E is DOCUMENT) {
                                immutable len = LEB128.decode!uint(data[value_pos .. $]);
                                return Value(Document(
                                        data[value_pos .. value_pos + len.size + len.value]));
                            }
                            else static if ((E is STRING) || (E is BINARY)) {
                                alias T = Value.TypeT!E;
                                alias U = ForeachType!T;
                                immutable binary_len = LEB128.decode!uint(data[value_pos .. $]);
                                immutable buffer_pos = value_pos + binary_len.size;
                                immutable buffer = (cast(immutable(U)*)(data[buffer_pos .. $].ptr))[0 .. binary_len
                                    .value];
                                return Value(buffer);
                            }
                            else static if (E is BIGINT) {
                                return Value(BigNumber(data[value_pos .. $]));
                            }
                            else static if (isDataBlock(E)) {
                                // immutable binary_len=LEB128.decode!uint(data[value_pos..$]);
                                // immutable buffer_pos=value_pos+binary_len.size;
                                // immutable buffer=data[buffer_pos..buffer_pos+binary_len.value];
                                return Value(DataBlock(data[value_pos .. $]));
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
                                        return Value(LEB128.decode!T(data[value_pos .. $]).value);
                                    }
                                    else {
                                        Value* result = cast(Value*)(&data[value_pos]);
                                        return *result;
                                    }
                                }
                            }
                            break TypeCase;
                        }
                    }
                default:
                    //empty
                }
                return Value.init;
                //                assert(0);
            }

            /**
             * @return the value as the HiBON type Type
             * @throw if the element does not contain the type E and HiBONException is thrown
             */
            auto by(Type E)() const {
                return value.by!E;
            }

            /**
             * @return the value as the type T
             * @throw if the element does not contain the type and HiBONException is thrown
             */
            @trusted const(T) get(T)() const {
                enum E = Value.asType!T;
                static assert(E !is Type.NONE, "Unsupported type " ~ T.stringof);
                return by!E;
            }

            /**
             * Tries to convert the value to the type T.
             * @return true if the function succeeds
             */
            bool as(T)(ref T result) {
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

            /**
             * @return the index of the key
             * @throw if the key is not an index an HiBONException is thrown
             */
            uint index() {
                return LEB128.decode!uint(data[keyPos .. $]).value;
            }

        }

        @property const pure {
            /**
             * @return true if the buffer block ends
             */
            bool isEod() {
                return data.length == 0;
            }

            /**
             * @return the Type of the element
             */
            Type type() {
                if (isEod) {
                    return Type.NONE;
                }
                return cast(Type)(data[0]);
            }

            /**
             * @return true if element key is an index
             */
        }
        bool isIndex() const {
            return data[Type.sizeof] is 0;
        }

        @property const {
            /**
             * @return the key length
             */
            uint keyLen() {
                if (isIndex) {
                    return cast(uint) LEB128.calc_size(data[keyPos .. $]);
                }
                return LEB128.decode!uint(data[Type.sizeof .. $]).value;
            }

            /**
             * @return the key
             */
            string key(ref Text key_index) {
                if (isIndex) {
                    key_index(LEB128.decode!uint(data[keyPos .. $]).value);
                    return key_index.serialize;
                }
                return cast(string) data[keyPos .. valuePos];
            }

            /**
             * @return the position of the value inside the element buffer
             */
            uint valuePos() {
                return keyPos + keyLen;
            }

            uint dataPos() {
                return valuePos + cast(uint) LEB128.calc_size(data[valuePos .. $]);
            }

            uint dataSize() {
                return LEB128.decode!uint(data[valuePos .. $]).value;
            }
            /**
             * @return the size of the element in bytes
             */
            size_t size() {
                with (Type) {
                TypeCase:
                    switch (type) {
                        static foreach (E; EnumMembers!Type) {
                    case E:
                            static if (isHiBONBaseType(E)) {
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
                                    return valuePos + LEB128.calc_size(data[valuePos .. $]);
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
                        return LEB128.calc_size(data);
                    }
                }
                return 0;
                // import std.format;
                // assert(0, format("Bad type %s", type));
                // Text error;
                // error("Bad type")(type);
                // assert(0, error.serialize);
            }

            enum ErrorCode {
                NONE, // No errors
                INVALID_NULL, // Invalid null object
                KEY_ORDER, // Error in the key order
                DOCUMENT_TYPE, // Warning document type
                TOO_SMALL, // Data stream is too small to contain valid data
                ILLEGAL_TYPE, // Use of internal types is illegal
                INVALID_TYPE, // Type is not defined
                OVERFLOW, // The specified data does not fit into the data stream
                ARRAY_SIZE_BAD // The binary-array size in bytes is not a multipla of element size in the array
            }

            /**
             * Check if the element is valid
             * @return the error code the element.
               ErrorCode.NONE means that the element is valid
            */
            @trusted ErrorCode valid() {
                enum MIN_ELEMENT_SIZE = Type.sizeof + ubyte.sizeof + char.sizeof + ubyte.sizeof;

                with (ErrorCode) {
                    if (type is Type.DOCUMENT) {
                        return DOCUMENT_TYPE;
                    }
                    if (data.length < MIN_ELEMENT_SIZE) {
                        if (data.length !is ubyte.sizeof) {
                            return TOO_SMALL;
                        }
                        else if (data[0]!is 0) {
                            return INVALID_NULL;
                        }
                    }
                TypeCase:
                    switch (type) {
                        static foreach (E; EnumMembers!Type) {
                    case E:
                            static if ((isNative(E) || (E is Type.DEFINED_ARRAY))) {
                                return ILLEGAL_TYPE;
                            }
                            break TypeCase;
                        }
                    default:
                        return INVALID_TYPE;
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
                    return NONE;
                }
            }
        }

        @property const pure {
            /**
             * Check if the type match That template.
             * That template must have one parameter T as follows
             * @return true if the element is the type That
            */
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
        }
        /**
         * Compare two elements
         */
        bool opEquals(ref const Element other) const {
            immutable s = size;
            if (s !is other.size) {
                return false;
            }
            return data[0 .. s] == other.data[0 .. s];
        }
    }
}
