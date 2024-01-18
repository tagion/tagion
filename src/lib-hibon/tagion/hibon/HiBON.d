/**
 * Implements HiBON
 * Hash-invariant Binary Object Notation
 * Is inspired by BSON but us not compatible
 *
 * See_Also:
 *  $(LINK2 http://bsonspec.org/, BSON - Binary JSON)
 *
 */
module tagion.hibon.HiBON;

version (REDBLACKTREE_SAFE_PROBLEM) {
    /// dmd v2.100+ has problem with rbtree
    /// Fix: This module hacks the @safe rbtree so it works with dmd v2.100 
    import tagion.std.container.rbtree : RedBlackTree;
}
else {
    import std.container.rbtree : RedBlackTree;
}

import std.algorithm.iteration : each, fold, map, sum;
import std.format;
import std.meta : staticIndexOf;
import std.traits : EnumMembers, ForeachType, Unqual, isMutable, isBasicType,
    isIntegral, OriginalType, ReturnType, hasMember, isAssociativeArray;
import std.conv : to;
import std.meta : AliasSeq;
import std.range : enumerate, isInputRange;
import std.typecons : TypedefType;
import tagion.basic.Message : message;
import tagion.basic.Types : Buffer, isTypedef;
import tagion.basic.basic : CastTo;
import tagion.hibon.BigNumber;
import tagion.hibon.Document;
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONRecord : isHiBON, isHiBONRecord, isHiBONTypeArray;
import LEB128 = tagion.utils.LEB128;
public import tagion.hibon.HiBONJSON;

//import std.stdio;

static size_t size(U)(const(U[]) array) pure {
    if (array.length is 0) {
        return ubyte.sizeof;
    }
    size_t _size;
    foreach (i, h; array) {
        immutable index_key = i.to!string;
        _size += Document.sizeKey(index_key);
        static if (__traits(compiles, h.size)) {
            const h_size = h.size;
        }
        else {
            const h_size = h.length;
        }
        _size += LEB128.calc_size(h_size) + h_size;
    }
    return _size;
}

/++
 HiBON is a generate object of the HiBON format
+/
@safe class HiBON {
    /++
     Gets the internal buffer
     Returns:
     The buffer of the HiBON document
    +/

    alias Value = ValueT!(true, HiBON, Document);

    this() nothrow pure {
        _members = new Members;
    }

    // import tagion.hibon.HiBONJSON : JSONString;
    // mixin JSONString;

    /++
     Calculated the size in bytes of HiBON payload
     Returns:
     the size in bytes
     +/
    size_t size() const pure {
        if (!_members[].empty) {
            return _members[]
                .map!(a => a.size)
                .sum;
            //            __write("HiBON.size = %d", result);
        }
        return ubyte.sizeof;
    }

    bool empty() const pure {
        return _members.empty;
    }
    /++
     Calculated the size in bytes of serialized HiBON
     Returns:
     the size in bytes
     +/
    size_t serialize_size() const pure {
        auto _size = size;
        if (_size !is ubyte.sizeof) {
            _size += LEB128.calc_size(_size);
        }
        return _size;
    }
    /++
     Generated the serialized HiBON
     Returns:
     The byte stream
     +/
    immutable(ubyte[]) serialize() const pure {
        AppendBuffer buffer;
        buffer.reserve(serialize_size);
        append(buffer);
        return buffer.data;
    }

    // /++
    //  Helper function to append
    //  +/
    private void append(ref scope AppendBuffer buffer) const pure {
        if (_members[].empty) {
            buffer ~= ubyte(0);
            return;
        }
        const size = cast(uint) _members[].map!(a => a.size).sum;

        buffer ~= LEB128.encode(size);
        _members[].each!(a => a.append(buffer));
    }

    /++
     Internal Member in the HiBON class
     +/
    @safe static class Member {
        const string key;
        immutable Type type;
        Value value;

        @nogc protected this(const string key) pure scope {
            this.key = key;
            type = Type.NONE;
        }

        alias CastTypes = AliasSeq!(uint, int, ulong, long, string);

        /++
         Params:
         x = the parameter value
         key = the name of the member
         +/
        @trusted this(T)(T x, string key) pure {
            static if (is(T == enum)) {
                alias UnqualT = Unqual!(OriginalType!T);
            }
            else {
                alias UnqualT = Unqual!T;
            }
            enum E = Value.asType!UnqualT;
            this.key = key;
            with (Type) {
                static if (E is NONE) {
                    alias BaseT = TypedefType!UnqualT;
                    static if (is(BaseT == Buffer)) {
                        alias CastT = Buffer;
                    }
                    else {
                        alias CastT = CastTo!(BaseT, CastTypes);
                        static assert(!is(CastT == void),
                                format("Type %s is not valid", T.stringof));

                    }
                    alias CastE = Value.asType!CastT;
                    this.type = CastE;
                    this.value = cast(CastT) x;

                }
                else {
                    this.type = E;
                    static if (E is BIGINT || E is BINARY) {
                        this.value = x;
                    }
                    else {
                        this.value = cast(UnqualT) x;
                    }
                }
            }
        }

        /++
         If the value of the Member contains a Document it returns it or else an error is asserted
         Returns:
         the value as a Document
         +/
        @trusted inout(HiBON) document() inout pure nothrow
        in {
            assert(type is Type.DOCUMENT);
        }
        do {
            return value.document;
        }

        /++
         Returns:
         The value as type T
         Throws:
         If the member does not match the type T and HiBONException is thrown
         +/
        T get(T)() const if (isHiBONRecord!T || isHiBON!T) {
            with (Type) {
                switch (type) {
                case DOCUMENT:
                    const h = value.by!DOCUMENT;
                    const doc = Document(h.serialize);
                    return T(doc);
                    break;
                case NATIVE_DOCUMENT:
                    const doc = value.by!NATIVE_DOCUMENT;
                    return T(doc);
                    break;
                default:

                    

                        .check(0, message("Expected HiBON type %s but apply type (%s) which is not supported",
                                type, T.stringof));
                }
            }
            assert(0);
        }

        const(T) get(T)() const if (!isHiBONRecord!T && !isHiBON!T && !isTypedef!T) {
            enum E = Value.asType!T;

            

            .check(E is type, message("Expected HiBON type %s but apply type %s (%s)",
                    type, E, T.stringof));
            return value.by!E;
        }

        inout(T) get(T)() inout if (Document.isDocTypedef!T) {
            alias BaseType = TypedefType!T;
            const ret = get!BaseType;
            return T(ret);
        }

        unittest {
            import std.typecons : Typedef;

            alias BUF = immutable(ubyte)[];
            alias Tdef = Typedef!(BUF, null, "SPECIAL");
            auto h = new HiBON;
            Tdef buf = [0x17, 0x42];
            h["b"] = buf;
            assert(Document(h)["b"].get!Tdef == buf);
        }
        /++
         Returns:
         The value as HiBON Type E
         Throws:
         If the member does not match the type T and HiBONException is thrown
         +/
        auto by(Type type)() inout {
            return value.by!type;
        }

        static const(Member) opCast(string key) pure {
            return new Member(key);
        }

        /++
         Calculates the size in bytes of the Member
         Returns:
         the size in bytes
         +/
        @trusted size_t size() const pure {
            with (Type) {
            TypeCase:
                switch (type) {
                    foreach (E; EnumMembers!Type) {
                        static if (isHiBONBaseType(E) || isNative(E)) {
                case E:
                            static if (E is Type.DOCUMENT) {
                                const _size = value.by!(E).size;
                                if (_size is 1) {
                                    return Document.sizeKey(key) + ubyte.sizeof;
                                }
                                return Document.sizeKey(key) + LEB128.calc_size(_size) + _size;
                            }
                            else static if (E is NATIVE_DOCUMENT) {
                                const _size = value.by!(E).size;
                                return Document.sizeKey(key) + LEB128.calc_size(_size) + _size;
                            }
                            else static if (isNativeArray(E)) {
                                size_t _size;
                                foreach (i, e; value.by!(E)[]) {
                                    immutable index_key = i.to!string;
                                    _size += Document.sizeKey(index_key);
                                    static if (E is NATIVE_HIBON_ARRAY || E is NATIVE_DOCUMENT_ARRAY) {
                                        const _doc_size = e.size;
                                        _size += LEB128.calc_size(_doc_size) + _doc_size;
                                    }
                                    else static if (E is NATIVE_STRING_ARRAY) {
                                        _size += LEB128.calc_size(e.length) + e.length;
                                    }
                                }
                                return Document.sizeKey(key) + LEB128.calc_size(_size) + _size;
                            }
                            else static if (E is VER) {
                                return LEB128.calc_size(HIBON_VERSION);
                            }
                            else {
                                const v = value.by!(E);
                                return Document.sizeT(E, key, v);
                            }
                            break TypeCase;
                        }
                    }
                default:
                    // Empty
                }
                assert(0, format("Size of HiBON type %s is not valid", type));
            }
        }

        @trusted protected void appendList(Type E)(ref scope AppendBuffer buffer) const pure
        if (isNativeArray(E)) {
            with (Type) {
                immutable list_size = value.by!(E).size;
                buffer ~= LEB128.encode(list_size);
                foreach (i, h; value.by!E) {
                    immutable key = i.to!string;
                    static if (E is NATIVE_STRING_ARRAY) {
                        build(buffer, STRING, key, h);
                    }
                    else {
                        buildKey(buffer, DOCUMENT, key);
                        static if (E is NATIVE_HIBON_ARRAY) {
                            h.append(buffer);
                        }
                        else static if (E is NATIVE_DOCUMENT_ARRAY) {
                            buffer ~= (h.data);
                        }
                        else {
                            assert(0, format("%s is not implemented yet", E));
                        }
                    }
                }
            }
        }

        void append(ref scope AppendBuffer buffer) const pure {
            with (Type) {
            TypeCase:
                switch (type) {
                    static foreach (E; EnumMembers!Type) {
                        static if (isHiBONBaseType(E) || isNative(E)) {
                case E:
                            alias T = Value.TypeT!E;
                            static if (E is DOCUMENT) {
                                buildKey(buffer, E, key);
                                value.by!(E).append(buffer);
                            }
                            else static if (isNative(E)) {
                                static if (E is NATIVE_DOCUMENT) {
                                    buildKey(buffer, DOCUMENT, key);
                                    buffer ~= value.by!(E).data;
                                }
                                else static if (isNativeArray(E)) {
                                    buildKey(buffer, DOCUMENT, key);
                                    appendList!E(buffer);
                                }
                                else {
                                    goto default;
                                }
                            }
                            else {
                                build(buffer, E, key, value.by!E);
                            }
                            break TypeCase;
                        }
                    }
                default:
                    assert(0, format("Illegal type %s", type));
                }
            }
        }
    }

    alias Members = RedBlackTree!(Member, (a, b) @safe => (less_than(a.key, b.key)));

    protected Members _members;

    /++
     Returns:
     A range of members with sorted keys
     +/
    auto opSlice() const {
        return _members[];
    }

    void opAssign(T)(T r) @trusted if ((isInputRange!T) && !isAssociativeArray!T) {
        foreach (i, a; r.enumerate) {
            opIndexAssign(a, i);
        }
    }

    @trusted
    unittest { // Check Array Range init
        import std.stdio;

        // import std.range : retro;
        import std.algorithm.comparison : equal;

        // import tagion.hibon.HiBONJSON;
        struct ArrayRange {
            int count;
            bool empty() {
                return count <= 0;
            }

            string front() {
                return format("text-%d", count);
            }

            void popFront() {
                count--;
            }
        }

        auto h = new HiBON;
        ArrayRange ar;
        ar.count = 3;
        h = ar;
        // writefln("Array %s", h.toPretty);
        assert(h.length == 3);
        assert(h.isArray);
        // ar.count = 3;
        // writefln("retro %s %s", h[].map!(a => a.get!string), ar);
        ar.count = 3;
        assert(equal(h[].map!(a => a.get!string), ar));

        // assert(0);
    }
    /++
     Assign and member x with the key
     Params:
     x = parameter value
     key = member key
     +/
    void opIndexAssign(T)(T x, const string key) if (isHiBON!T) {
        opIndexAssign(x.toHiBON, key);
    }

    void opIndexAssign(T)(T x, const string key) if (isHiBONTypeArray!T) {
        auto h = new HiBON;
        foreach (v_key, v; x) {
            h[v_key] = x;
        }
        h[key] = h;
    }

    void opIndexAssign(T)(T x, const string key) @trusted if (!isHiBON!T && !isHiBONRecord!T && !isHiBONTypeArray!T) {

        

            .check(is_key_valid(key), message("Key is not a valid format '%s'", key));
        Member new_member = new Member(x, key);

        

        .check(_members.insert(new_member) is 1, message("Element member %s already exists", key));
    }

    /++
     Assign and member x with the index
     Params:
     x = parameter value
     index = member index
     +/
    void opIndexAssign(T, INDEX)(T x, const INDEX index) if (isIntegral!INDEX) {
        static if (INDEX.max > uint.max) {

            

                .check(index <= uint.max, message("Index out of range (index=%d)", index));
        }
        static if (INDEX.min < uint.min) {

            

                .check(index >= uint.min, message("Index must be zero or positive (index=%d)", index));
        }
        const key = index.to!string;
        opIndexAssign(x, key);
    }

    /++
     Access an member at key
     Params:
     key = member key
     Returns:
     the Member at the key
     Throws:
     if the an member with the key does not exist an HiBONException is thrown
     +/
    const(Member) opIndex(const string key) const {
        auto search = new Member(key);
        auto range = _members.equalRange(search);

        

        .check(!range.empty, message("Member '%s' does not exist", key));
        return range.front;
    }

    /++
     Access an member at index
     Params:
     index = member index
     Returns:
     the Member at the index
     Throws:
     if the an member with the index does not exist an HiBONException is thrown
     Or an std.conv.ConvException is thrown if the key is not an index
     +/
    const(Member) opIndex(INDEX)(const INDEX index) const if (isIntegral!INDEX) {
        static if (INDEX.max > uint.max) {

            

                .check(index <= uint.max, message("Index out of range (index=%d)", index));
        }
        static if (INDEX.min < uint.min) {

            

                .check(index >= uint.min, message("Index must be zero or positive (index=%d)", index));
        }
        const key = index.to!string;
        return opIndex(key);
    }

    /++
     Params:
     key = member key
     Returns:
     true if the member with the key exists
     +/
    bool hasMember(const string key) const {
        auto range = _members.equalRange(new Member(key));
        return !range.empty;
    }
    /++
     Params:
     index = member index
     Returns:
     true if the member with the key exists
     +/

    bool hasMember(INDEX)(const INDEX index) const if (isIntegral!INDEX) {
        const key = index.to!string;
        scope search = new Member(key);
        auto range = _members.equalRange(search);
        return !range.empty;
    }

    /++
     Removes a member with name of key
     Params:
     key = name of the member to be removed
     +/
    @trusted void remove(const string key) {
        scope search = new Member(key);
        _members.removeKey(search);
    }

    ///
    unittest { // remove
        auto hibon = new HiBON;
        hibon["a"] = 1;
        hibon["b"] = 2;
        hibon["c"] = 3;
        hibon["d"] = 4;

        assert(hibon.hasMember("b"));
        hibon.remove("b");
        assert(!hibon.hasMember("b"));
    }

    /++
     Removes a member with name of key
     Params:
     key = name of the member to be removed
     +/
    @trusted void remove(INDEX)(const INDEX index) if (isIntegral!INDEX) {
        static if (INDEX.max > uint.max) {

            

                .check(index <= uint.max, message("Index out of range (index=%d)", index));
        }
        static if (INDEX.min < uint.min) {

            

                .check(index >= uint.min, message("Index must be zero or positive (index=%d)", index));
        }
        const key = index.to!string;
        scope search = new Member(key);
        _members.removeKey(search);
    }

    unittest {
        auto hibon = new HiBON;
        hibon[0] = 0;
        hibon[1] = 1;
        hibon[2] = 2;
        assert(hibon.hasMember(0));
        assert(hibon.hasMember(1));
        assert(hibon.hasMember(2));
        assert(!hibon.hasMember(3));

        hibon.remove(1);
        assert(!hibon.hasMember(1));
    }

    /++
     Returns:
     the number of members in the HiBON
     +/
    size_t length() const {
        return _members.length;
    }

    /++
     Returns:
     A range of the member keys
     +/
    auto keys() const {
        return map!"a.key"(this[]);
    }

    /++
     Returns:
     A range of indices
     Throws:
     The range will throw an std.conv.ConvException if the key is not an index
    +/
    auto indices() const {
        return map!"a.key.to!uint"(this[]);
    }

    /++
     Check if the HiBON is an Array
     Returns:
     true if all keys is indices and are consecutive
     +/
    bool isArray() const {
        return .isArray(keys);
    }

    ///
    unittest {
        {
            auto hibon = new HiBON;
            assert(hibon.isArray);

            hibon["0"] = 1;
            assert(hibon.isArray);
            hibon["1"] = 2;
            assert(hibon.isArray);
            hibon["2"] = 3;
            assert(hibon.isArray);
            hibon["x"] = 3;
            assert(!hibon.isArray);
        }
        {
            auto hibon = new HiBON;
            hibon["1"] = 1;
            assert(!hibon.isArray);
            hibon["0"] = 2;
            assert(hibon.isArray);
            hibon["4"] = 3;
            assert(!hibon.isArray);
            hibon["3"] = 4;
            assert(!hibon.isArray);
            hibon["2"] = 7;
            assert(hibon.isArray);
            hibon["05"] = 2;
            assert(!hibon.isArray);
        }
    }

    unittest {
        // import std.stdio;
        import std.conv : to;
        import std.typecons : Tuple, isTuple;

        // Note that the keys are in alphabetic order
        // Because the HiBON keys must be ordered
        alias Tabel = Tuple!(BigNumber, Type.BIGINT.stringof, bool, Type.BOOLEAN.stringof,
                float, Type.FLOAT32.stringof, double, Type.FLOAT64.stringof,
                int, Type.INT32.stringof, long, Type.INT64.stringof, uint,
                Type.UINT32.stringof, ulong, Type.UINT64.stringof, //                utc_t,  Type.UTC.stringof

                

        );

        Tabel test_tabel;
        test_tabel.FLOAT32 = 1.23;
        test_tabel.FLOAT64 = 1.23e200;
        test_tabel.INT32 = -42;
        test_tabel.INT64 = -0x0123_3456_789A_BCDF;
        test_tabel.UINT32 = 42;
        test_tabel.UINT64 = 0x0123_3456_789A_BCDF;
        test_tabel.BOOLEAN = true;
        test_tabel.BIGINT = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");

        // Note that the keys are in alphabetic order
        // Because the HiBON keys must be ordered
        alias TabelArray = Tuple!(
                immutable(ubyte)[], Type.BINARY.stringof, // Credential,          Type.CREDENTIAL.stringof,
                string, Type.STRING.stringof,);

        TabelArray test_tabel_array;
        test_tabel_array.BINARY = [1, 2, 3];
        test_tabel_array.STRING = "Text";

        { // empty
            auto hibon = new HiBON;
            assert(hibon.length is 0);

            assert(hibon.size is ubyte.sizeof);
            immutable data = hibon.serialize;

            const doc = Document(data);
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        { // Single element
            auto hibon = new HiBON;
            enum pos = 2;
            static assert(is(test_tabel.Types[pos] == float));
            hibon[test_tabel.fieldNames[pos]] = test_tabel[pos];

            assert(hibon.length is 1);

            const m = hibon[test_tabel.fieldNames[pos]];

            assert(m.type is Type.FLOAT32);
            assert(m.key is Type.FLOAT32.stringof);
            assert(m.get!(test_tabel.Types[pos]) == test_tabel[pos]);
            assert(m.by!(Type.FLOAT32) == test_tabel[pos]);

            immutable size = hibon.serialize_size;

            // This size of a HiBON with as single element of the type FLOAT32
            enum hibon_size = LEB128.calc_size(
                        14) // Size of the object in ubytes (uint(14))
                + Type.sizeof // The HiBON Type  (Type.FLOAT32)  1
                + ubyte.sizeof // Length of the key (ubyte(7))    2
                + Type.FLOAT32.stringof.length // The key text string ("FLOAT32") 9
                + float.sizeof // The data            (float(1.23)) 13
                //    + Type.sizeof                    // The HiBON object ends with a (Type.NONE) 14
                ;

            const doc_size = Document.sizeT(Type.FLOAT32, Type.FLOAT32.stringof, test_tabel[pos]);

            assert(size is hibon_size);
            assert(size is LEB128.calc_size(14) + doc_size);

            immutable data = hibon.serialize;

            const doc = Document(data);

            assert(doc.length is 1);
            const e = doc[Type.FLOAT32.stringof];

            assert(e.type is Type.FLOAT32);
            assert(e.key == Type.FLOAT32.stringof);
            assert(e.by!(Type.FLOAT32) == test_tabel[pos]);

        }

        { // HiBON Test for basic types
            auto hibon = new HiBON;
            string[] keys;
            foreach (i, t; test_tabel) {
                hibon[test_tabel.fieldNames[i]] = t;
                keys ~= test_tabel.fieldNames[i];
            }

            size_t index;
            foreach (m; hibon[]) {
                assert(m.key == keys[index]);
                index++;
            }

            foreach (i, t; test_tabel) {

                enum key = test_tabel.fieldNames[i];

                const m = hibon[key];
                assert(m.key == key);
                assert(m.type.to!string == key);
                assert(m.get!(test_tabel.Types[i]) == t);
            }

            immutable data = hibon.serialize;
            const doc = Document(data);
            assert(doc.length is test_tabel.length);

            foreach (i, t; test_tabel) {
                enum key = test_tabel.fieldNames[i];

                const e = doc[key];
                assert(e.key == key);
                assert(e.type.to!string == key);
                assert(e.get!(test_tabel.Types[i]) == t);
            }
        }

        { // HiBON Test for none basic types
            auto hibon = new HiBON;

            string[] keys;
            foreach (i, t; test_tabel_array) {
                hibon[test_tabel_array.fieldNames[i]] = t;
                keys ~= test_tabel_array.fieldNames[i];
            }

            size_t index;
            foreach (m; hibon[]) {
                assert(m.key == keys[index]);
                index++;
            }

            foreach (i, t; test_tabel_array) {
                enum key = test_tabel_array.fieldNames[i];
                const m = hibon[key];
                assert(m.key == key);
                assert(m.type.to!string == key);
                assert(m.get!(test_tabel_array.Types[i]) == t);
            }

            immutable data = hibon.serialize;
            const doc = Document(data);
            assert(doc.length is test_tabel_array.length);

            foreach (i, t; test_tabel_array) {
                enum key = test_tabel_array.fieldNames[i];
                const e = doc[key];
                assert(e.key == key);
                assert(e.type.to!string == key);
                assert(e.get!(test_tabel_array.Types[i]) == t);
            }

        }

        { // HIBON test containg an child HiBON
            auto hibon = new HiBON;
            auto hibon_child = new HiBON;
            enum chile_name = "child";

            hibon["string"] = "Text";
            hibon["float"] = float(1.24);

            immutable hibon_size_no_child = hibon.serialize_size;
            hibon[chile_name] = hibon_child;
            hibon_child["int32"] = 42;

            immutable hibon_child_size = hibon_child.serialize_size;
            immutable child_key_size = Document.sizeKey(chile_name);
            immutable hibon_size = hibon.serialize_size;

            assert(hibon_size is hibon_size_no_child + child_key_size + hibon_child_size);

            immutable data = hibon.serialize;
            const doc = Document(data);
        }

        { // Use of native Documet in HiBON
            auto native_hibon = new HiBON;
            native_hibon["int"] = int(42);
            immutable native_data = native_hibon.serialize;
            auto native_doc = Document(native_hibon.serialize);

            auto hibon = new HiBON;
            hibon["string"] = "Text";

            immutable hibon_no_native_document_size = hibon.size;
            hibon["native"] = native_doc;
            immutable data = hibon.serialize;
            const doc = Document(data);

            {
                const e = doc["string"];
                assert(e.type is Type.STRING);
                assert(e.get!string == "Text");
            }

            { // Check native document
                const e = doc["native"];

                assert(e.type is Type.DOCUMENT);
                const sub_doc = e.get!Document;
                assert(sub_doc.length is 1);
                assert(sub_doc.data == native_data);
                const sub_e = sub_doc["int"];
                assert(sub_e.type is Type.INT32);
                assert(sub_e.get!int  is 42);
            }
        }

        { // Document array
            HiBON[] hibon_array;
            alias TabelDocArray = Tuple!(int, "a", string, "b", float, "c");
            TabelDocArray tabel_doc_array;
            tabel_doc_array.a = 42;
            tabel_doc_array.b = "text";
            tabel_doc_array.c = 42.42;

            foreach (i, t; tabel_doc_array) {
                enum name = tabel_doc_array.fieldNames[i];
                auto local_hibon = new HiBON;
                local_hibon[name] = t;
                hibon_array ~= local_hibon;
            }

            // foreach(k, h; hibon_array) {
            //     writefln("hibon_array[%s].size=%d", k, h.size);
            //     writefln("hibon_array[%s].serialize=%s", k, h.serialize);
            // }
            // writefln("\thibon_array.size=%d", hibon_array.size);

            auto hibon = new HiBON;
            hibon["int"] = int(42);
            hibon["array"] = hibon_array;

            // immutable data_array = hibon_array.serialize;
            // writefln("data=%s", data_array);
            // writefln("data_array.length=%d size=%d", data_array.length, hibon_array.size);
            // writefln("hibon.serialize=%s", hibon.serialize);
            immutable data = hibon.serialize;

            const doc = Document(data);

            {
                // //                writefln(`doc["int"].type=%d`, doc["int"].type);
                //                 writeln("-------------- --------------");
                //                 auto test=doc["int"];
                //                 writeln("-------------- get  --------------");
                assert(doc["int"].get!int  is 42);
            }

            {
                const doc_e = doc["array"];
                assert(doc_e.type is Type.DOCUMENT);
                const doc_array = doc_e.by!(Type.DOCUMENT);
                foreach (i, t; tabel_doc_array) {
                    enum name = tabel_doc_array.fieldNames[i];
                    alias U = tabel_doc_array.Types[i];
                    const doc_local = doc_array[i].by!(Type.DOCUMENT);
                    const local_e = doc_local[name];
                    assert(local_e.type is Value.asType!U);
                    assert(local_e.get!U == t);
                }
            }

            { // Test of Document[]
                Document[] docs;
                foreach (h; hibon_array) {
                    docs ~= Document(h.serialize);
                }

                auto hibon_doc_array = new HiBON;
                hibon_doc_array["doc_array"] = docs;
                hibon_doc_array["x"] = 42;

                assert(hibon_doc_array.length is 2);

                immutable data_array = hibon_doc_array.serialize;

                const doc_all = Document(data_array);
                const doc_array = doc_all["doc_array"].by!(Type.DOCUMENT);

                foreach (i, t; tabel_doc_array) {
                    enum name = tabel_doc_array.fieldNames[i];
                    alias U = tabel_doc_array.Types[i];
                    alias E = Value.asType!U;
                    const e = doc_array[i];
                    const doc_e = e.by!(Type.DOCUMENT);
                    const sub_e = doc_e[name];
                    assert(sub_e.type is E);
                    assert(sub_e.by!E == t);
                }

            }

        }

        { // Test of string[]
            auto texts = ["Hugo", "Vigo", "Borge"];
            auto hibon = new HiBON;
            hibon["texts"] = texts;

            immutable data = hibon.serialize;
            const doc = Document(data);
            const doc_texts = doc["texts"].by!(Type.DOCUMENT);
            assert(doc_texts.length is texts.length);
            foreach (i, s; texts) {
                const e = doc_texts[i];
                assert(e.type is Type.STRING);
                assert(e.get!string == s);
            }
        }
    }

    unittest { // Check empty/null object
    {
            HiBON hibon = new HiBON;
            auto sub = new HiBON;
            assert(sub.size == ubyte.sizeof);
            const sub_doc = Document(sub.serialize);
            hibon["a"] = sub_doc;
            assert(hibon.size == Type.sizeof + ubyte.sizeof + "a".length + sub.size);

        }

        {
            HiBON hibon = new HiBON;
            auto sub = new HiBON;
            assert(sub.size == ubyte.sizeof);
            hibon["a"] = sub;
            assert(hibon.size == Type.sizeof + ubyte.sizeof + "a".length + sub.size);
        }
    }

    unittest { // Override of a key is not allowed
        import std.exception : assertNotThrown, assertThrown;

        enum override_key = "okey";
        auto h = new HiBON;
        h[override_key] = 42;

        assert(h[override_key].get!int  is 42);
        assertThrown!HiBONException(h[override_key] = 17);

        h.remove(override_key);
        assertNotThrown!Exception(h[override_key] = 17);
        assert(h[override_key].get!int  is 17);

    }

    unittest { // Test sdt_t
        import std.typecons : TypedefType;
        import tagion.utils.StdTime;

        auto h = new HiBON;
        enum time = "$t";
        h[time] = sdt_t(1_100_100_101);

        const doc = Document(h);
        assert(doc[time].type is Type.TIME);
        assert(doc[time].get!sdt_t == 1_100_100_101);
    }

    unittest { // Test of empty Document
        import std.stdio;

        enum doc_name = "$doc";
        { // Buffer with empty Document
            auto h = new HiBON;
            immutable(ubyte[]) empty_doc_buffer = [0];
            h[doc_name] = Document(empty_doc_buffer);
            {
                const doc = Document(h);
                assert(doc[doc_name].get!Document.empty);
            }
            h[int.stringof] = 42;

            {
                const doc = Document(h);
                auto range = doc[];
                assert(range.front.get!Document.empty);
                range.popFront;
                assert(range.front.get!int  is 42);
                range.popFront;
                assert(range.empty);
            }

        }

        { // Empty buffer
            auto h = new HiBON;
            h[doc_name] = Document();
            {
                const doc = Document(h);
                assert(doc[doc_name].get!Document.empty);
            }
            h[int.stringof] = 42;

            {
                const doc = Document(h);
                auto range = doc[];
                assert(range.front.get!Document.empty);
                range.popFront;
                assert(range.front.get!int  is 42);
                range.popFront;
                assert(range.empty);
            }
        }
    }

}
