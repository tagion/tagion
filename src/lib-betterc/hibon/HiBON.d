/**
 * Implements HiBON
 * Hash-invariant Binary Object Notation
 * Is inspired by BSON but us not compatible
 *
 * See_Also:
 *  $(LINK2 http://bsonspec.org/, BSON - Binary JSON)
 *
 */
module hibon.HiBON;

extern(C):
@nogc:
//import std.container : RedBlackTree;
//import std.format;
import std.meta : staticIndexOf;
//import std.algorithm.iteration : map, fold, each;
import std.traits : EnumMembers, ForeachType, Unqual, isMutable, isBasicType, PointerTarget;
import std.meta : AliasSeq;

//import std.conv : to;
//import std.typecons : TypedefType;

import hibon.BigNumber;
import hibon.Document;
import hibon.HiBONBase;
import hibon.utils.Bailout;
import hibon.utils.RBTree;
import hibon.utils.Memory;
import hibon.utils.Text;
import hibon.utils.BinBuffer;
import hibon.utils.Basic;
import LEB128=hibon.utils.LEB128;

import hibon.utils.platform;
//import core.stdc.stdio;

HiBONT HiBON() {
    HiBONT result=HiBONT(RBTree!(HiBONT.Member*)(), true, false);
    return result;
}

/++
 HiBON is a generate obje52ct of the HiBON format
 +/
struct HiBONT {
    @nogc:
    /++
     Gets the internal buffer
     Returns:
     The buffer of the HiBON document
     +/
    alias Members=RBTreeT!(Member*);

//     RedBlackTree!(Member, (a, b) => (less_than(a.key, b.key)));
    private {
        Members _members;
        bool _owns;
        bool _readonly;
        bool _self_destruct;
        BinBuffer _buffer;
    }

    uint error;

    alias Value=ValueT!(true, HiBONT*,  Document);

    ~this() {
        dispose;
    }

    void dispose() {
        if (_owns) {
            _members.dispose;
        }
        else {
            _members.surrender;
        }
        _buffer.dispose;
        if ( _self_destruct ) {
            HiBONT* self=&this;
            .dispose!false(self);
        }
    }

    invariant {
        assert(_owns || (!_owns && _readonly));
    }

    /++
     Calculated the size in bytes of HiBON payload
     Returns:
     the size in bytes
     +/
    size_t size()  const {
        size_t result;
        foreach(n; _members[]) {
            result+=n.size;
        }
        if (result>0) {
            return result; //+calc_size(result);
        }
        else {
            return ubyte.sizeof;
        }
    }

    /++
     Calculated the size in bytes of serialized HiBON
     Returns:
     the size in bytes
     +/
    size_t serialize_size() const {
        auto _size=size;
        if (_size !is ubyte.sizeof ) {
            _size += LEB128.calc_size(_size);
        }
        return _size;
    }


    /++
     Expropriate the members to the return
     Returns:
     The new owner of the members
     +/
    HiBONT* expropriate() {
        auto result=create!(HiBONT);
        // Surrender the RBTree to the result;
        result._members=_members.expropriate;
        result._owns=true;
        result._self_destruct=true;
        _readonly=true;
        _owns=false;


//        expropriate;
        return result;
    }

    @property bool readonly() const pure {
        return _readonly;
    }

    @property bool owns() const pure {
        return _owns;
    }

    /++
     Generated the serialized HiBON
     Returns:
     The byte stream
     +/
    immutable(ubyte[]) serialize() {
        _buffer.recreate(serialize_size);
        append(_buffer);
        return _buffer.serialize;
    }

    // /++
    //  Helper function to append
    //  +/
    private void append(ref BinBuffer buffer) const {
        if (_members.empty) {
            buffer.write(ubyte(0));
        }
        else {
            uint size;
            foreach(m; _members[]) {
                size+=m.size;
            }
            LEB128.encode(buffer, size);
            foreach(n; _members[]) {
                n.append(buffer);
            }
        }
    }

    /++
     Internal Member in the HiBON class
     +/
    struct Member {
        @nogc:
        private {
            char[] _key;
            Type _type;
            Value _value;
        }

        int opCmp(ref const(Member*) b) const pure {
            return opCmp(b._key);
        }

        int opCmp(const(char[]) key) const pure {
            if (this._key == key) {
                return 0;
            }
            else if (this._key < key) {
                return -1;
            }
            return 1;
        }

        bool opEquals(T)(T b) const pure {
            return opCmp(b) == 0;
        }

        alias CastTypes=AliasSeq!(uint, int, ulong, long, string);
        /++
         Params:
         x = the parameter value
         key = the name of the member
         +/

        this(T)(T x, in const(char[]) key) {
            .create(this._key, key);
            void _init(S)(S x) {
                enum E=Value.asType!S;
                this._type=E;
                static if (.isArray(E)) {
                    alias U=Unqual!(ForeachType!S);
                    U[] temp_x;
                    temp_x.create(x);
                    this._value=cast(S)temp_x;
                }
                else static if (E is Type.BIGINT) {
                    this._value=x;
                }
                else {
                    this._value= cast(UnqualT)x;
                }

            }
            alias UnqualT = Unqual!T;
            enum E=Value.asType!UnqualT;
            static if (E is Type.NONE) {
                alias CastT=CastTo!(UnqualT, CastTypes);
                static assert(!is(CastT==void), "Type "~T.stringof~" is not valid");
                _init(x);
            }
            else {
                _init(x);
            }

        }

        private this(in const(char[]) key) {
            _key=Text(key).expropriate;
        }

        private this(in size_t index) {
            _key=Text(index).expropriate;
        }

        static Member* create(T)(T x, in const(char[]) key) {
            // auto new_member=Member(x, key);
            // scope(exit) {
            //     new_member._key=null;
            // }
            auto result=.create!Member(x, key);
            // result._key=new_nember._key;
            // result._type=new_member._type;
            // result._value=new_member._value;
            return result;
        }

        @property const pure {
            Type type() {
                return _type;
            }

            string key() {
                return cast(immutable)_key;
            }

            Value value() {
                return _value;
            }

            size_t key_size() {
                uint index;
                if (is_index(_key, index)) {
                    return ubyte.sizeof+LEB128.calc_size(index);
                }
                return LEB128.calc_size(_key.length)+_key.length;
            }
        }

        ~this() {
            dispose;
        }

        void dispose() {
            with(Type) {
            TypeCase:
                final switch(type) {
                    static foreach(E; EnumMembers!Type) {
                    case E:
                        static if (.isArray(E)) {
                            alias U=Unqual!(ForeachType!(Value.TypeT!E));
                            auto remove_this=cast(U[])value.by!E;
                            .dispose(remove_this);
                        }
                        else static if (E is Type.DOCUMENT) {
                            alias T=Unqual!(PointerTarget!(Value.TypeT!E));
                            auto sub=value.by!(E);
                            auto remove_this=cast(T*)(value.by!(E));
                            remove_this.dispose;
                        }
                        break TypeCase;
                    }
                }
            }
            _key.dispose;
        }

        /++
         If the value of the Member contains a Document it returns it or else an error is asserted
         Returns:
         the value as a Document
         +/

        const(HiBONT*) document() const pure
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
        const(T) get(T)() const {
            enum E = Value.asType!T;
            .check(E is type, message("Expected HiBON type %s but apply type %s (%s)", type, E, T.stringof));
            return value.by!E;
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


        /++
         Calculates the size in bytes of the Member
         Returns:
         the size in bytes
         +/

        size_t size() const {
            with(Type) {
            TypeCase:
                switch(type) {
                    foreach(E; EnumMembers!Type) {
                        static if(isHiBONType(E) || isNative(E)) {
                        case E:
                            static if ( E is Type.DOCUMENT ) {
                                const _size = value.by!(E).size;
                                if (_size is 1) {
                                    return Document.sizeKey(key) + ubyte.sizeof;
                                }
                                return Document.sizeKey(key) + LEB128.calc_size(_size) + _size;
                            }
                            else static if ( E is NATIVE_DOCUMENT ) {
                                const _size = value.by!(E).size;
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
                assert(0, "Size of HiBON type %s is not valid");
            }
        }

        protected void appendList(Type E)(ref BinBuffer buffer)  const if (isNativeArray(E)) {
            immutable size_index = buffer.length;
            buffer.write(uint.init);
            scope(exit) {
                buffer.write(Type.NONE);
                immutable doc_size=cast(uint)(buffer.length - size_index - uint.sizeof);
                buffer.write(doc_size);
            }
            with(Type) {
                foreach(i, h; value.by!E) {
                    const key=Text()(i);
                    //immutable key=i.to!string;
                    static if (E is NATIVE_STRING_ARRAY) {
                        Document.build(buffer, STRING, key.serialize, h);
                    }
                    else {
                        Document.buildKey(buffer, DOCUMENT, key.serialize);
                        static if (E is NATIVE_HIBON_ARRAY) {
                            h.append(buffer);
                        }
                        else static if (E is NATIVE_DOCUMENT_ARRAY) {
                            buffer.write(h.data);
                        }

                        else {
                            assert(0, "Support is not implemented yet");
                        }
                    }
                }
            }

        }

        void append(ref BinBuffer buffer) const {
            with(Type) {
            TypeCase:
                switch(type) {
                    static foreach(E; EnumMembers!Type) {
                        static if(isHiBONType(E) || isNative(E)) {
                        case E:
                            alias T = Value.TypeT!E;
                            static if (E is DOCUMENT) {
                                Document.buildKey(buffer, E, key);
                                value.by!(E).append(buffer);
                            }
                            else static if (isNative(E)) {
                                static if (E is NATIVE_DOCUMENT) {
                                    Document.buildKey(buffer, DOCUMENT, key);
                                    const doc=value.by!(E);
                                    buffer.write(value.by!(E).data);
                                }
                                else {
                                    goto default;
                                }
                            }
                            else {
                                alias U=typeof(value.by!E());
                                static if (is(U==const(float))) {
                                    auto x=value.by!E;
                                }
                                Document.build(buffer, E, key, value.by!E);
                            }
                            break TypeCase;
                        }
                    }
                default:
                    assert(0, "Illegal type");
                }
            }
        }
    }

    /++
     Returns:
     A Range of members
     +/
    Members.Range opSlice() const {
        return _members[];
    }

    void opIndexAssign(ref HiBONT x, in const(char[]) key) {
        if (!readonly && is_key_valid(key)) {
            auto new_x=x.expropriate;
            // auto new_member=Member(new_x, key);
            // scope(exit) {
            //     new_member._key=null;
            // }
            // char[] new_key;
            // create(new_key, key);
            auto new_member=Member.create(new_x, key);
            _members.insert(new_member);
        }
        else {
            error++;
        }
    }

    /++
     Assign and member x with the key
     Params:
     x = parameter value
     key = member key
     +/
    void opIndexAssign(T)(T x, in const(char[]) key) if (!is(T:const(HiBONT))) {
        if (!readonly && is_key_valid(key)) {
            auto new_member=create!Member(x, key);
            _members.insert(new_member);
        }
        else {
            error++;
        }
    }

    /++
     Assign and member x with the index
     Params:
     x = parameter value
     index = member index
     +/
    void opIndexAssign(T)(T x, const size_t index) if (!is(T:const(HiBONT))) {
        if (index <= uint.max) {
            auto _key=Key(cast(uint)index);
            opIndexAssign(x, _key.serialize);
        }
        else {
            error++;
        }
    }

    void opIndexAssign(ref HiBONT x, const size_t index) {
        if (index <=uint.max) {
            Text key_text;
            key_text(index);
            //auto _key=Key(cast(uint)index);
            this[key_text.serialize]=x;
        }
        else {
            error++;
        }
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
    const(Member*) opIndex(in const(char[]) key) const {
        auto m=Member(key);
        return _members.get(&m);
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

    const(Member*) opIndex(const size_t index) {
        if (index <= uint.max) {
            auto m=Member(index);
            return _members.get(&m);
        }
        error++;
        return null;
    }

    /++
     Params:
     key = member key
     Returns:
     true if the member with the key exists
     +/
    bool hasMember(in const(char[]) key) const {
        auto m=Member(key);
        return _members.exists(&m);
    }

    /++
     Removes a member with name of key
     Params:
     key = name of the member to be removed
     +/
    void remove(in const(char[]) key) {
        auto m=Member(key);
        _members.remove(&m);
    }

    ///
    unittest { // remove
        auto hibon=HiBON();
        hibon["d"] =4;
        hibon["b"] =2;
        hibon["c"] =3;
        hibon["a"] =1;

        assert(hibon.hasMember("b"));
        hibon.remove("b");
        assert(!hibon.hasMember("b"));
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
     A list of the member keys
     +/
    KeyRange keys() const {
        return KeyRange(&this);
    }

    protected struct KeyRange {
        @nogc:
        Members.Range range;
        this(const(HiBONT*) owner) {
            range=owner.opSlice;
        }
        ~this() {
            range.dispose;
        }

        @property bool empty() const pure {
            return range.empty;
        }

        @property void popFront() {
            range.popFront;
        }

        string front() {
            return range.front.key;
        }
    }

    /++
     A list of indices
     Returns:
     returns false if some index is not a number;
     +/
    IndexRange indices() const {
        return IndexRange(&this);
    }

    protected struct IndexRange {
        @nogc:
        private {
            Members.Range range;
            bool _error;
        }
        this(const(HiBONT*) owner) {
            range=owner.opSlice;
        }
        ~this() {
            range.dispose;
        }

        @property bool empty() const pure {
            return range.empty;
        }

        @property  void popFront() {
            range.popFront;
        }

        uint front()  {
            uint index;
            if (!is_index(range.front.key, index)) {
                _error=true;
            }
            return index;
        }

        @property error() const pure {
            return _error;
        }
    }


    /++
     Check if the HiBON is an Array
     Returns:
     true if all keys is indices and are consecutive
     +/
    bool isArray() const {
        auto range=indices;
        long prev_index=-1;
        while(!range.empty) {
            const index=range.front;
            if (range.error || (prev_index+1 != index)) {
                return false;
            }
            prev_index=index;
            range.popFront;
        }
        return true;
    }

    int last_index() {
        int result=-1;
        auto range=indices;
        while (!range.empty) {
            const index=range.front;
            if (!range.error) {
                result=index;
            }
            range.popFront;
        }
        return result;
    }

    void opOpAssign(string op)(ref HiBONT cat) if (op == "~") {
        const index=cast(uint)(last_index+1);
        this[index]=cat;
    }

    void opOpAssign(string op, T)(T cat) if (op == "~") {
        const index=cast(uint)(last_index+1);
        this[index]=cat;
    }


    ///
    unittest {
        {
            auto hibon=HiBON();
            assert(hibon.isArray);

            hibon["0"]=1;
            assert(hibon.isArray);
            hibon["1"]=2;
            assert(hibon.isArray);
            hibon["2"]=3;
            assert(hibon.isArray);
            hibon["x"]=3;
            assert(!hibon.isArray);
        }
        {
            auto hibon=HiBON();
            hibon["1"]=1;
            assert(!hibon.isArray);
            hibon["0"]=2;
            assert(hibon.isArray);
            hibon["4"]=3;
            assert(!hibon.isArray);
            hibon["3"]=4;
            assert(!hibon.isArray);
            hibon["2"]=7;
            assert(hibon.isArray);
            hibon["05"]=2;
            assert(!hibon.isArray);
        }
    }

    unittest {
        struct Table {
            bool  BOOLEAN;
            float FLOAT32;
            double FLOAT64;
            //     BigNumberBIGINT;

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
        //test_tabel.BIGINT   = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");

        { // empty
            auto hibon = HiBON();
            assert(hibon.length is 0);

            assert(hibon.size is ubyte.sizeof);
            immutable data = hibon.serialize;

            const doc = Document(data);
            assert(doc.length is 0);
            assert(doc[].empty);
        }

        // Note that the keys are in alphabetic order
        // Because the HiBON keys must be ordered
        { // Single element
            auto hibon = HiBON();
            enum pos=1;
            alias A=typeof(test_table[pos]);

            static assert(is(typeof(test_table[pos]) == float));
            alias M=typeof(test_table[pos]);
            enum key = basename!(table.tupleof[pos]);

            hibon[key] = test_table[pos];

            assert(hibon.length is 1);

            const m=hibon[key];
            assert(m.type is Type.FLOAT32);
            assert(m.key == key);
            assert(m.get!(M) == test_table[pos]);
            assert(m.by!(Type.FLOAT32) == test_table[pos]);

            immutable size = hibon.serialize_size;
            // This size of a HiBON with as single element of the type FLOAT32
            enum hibon_size
                = LEB128.calc_size(14)           // Size of the object in ubytes (uint(14))
                + Type.sizeof                    // The HiBON Type  (Type.FLOAT32)  1
                + ubyte.sizeof                   // Length of the key (ubyte(7))    2
                + Type.FLOAT32.stringof.length   // The key text string ("FLOAT32") 9
                + float.sizeof                   // The data            (float(1.23)) 13
                ;

            const doc_size = Document.sizeT(Type.FLOAT32, Type.FLOAT32.stringof, test_table[pos]);

            assert(size is hibon_size);
            assert(size is LEB128.calc_size(14)+doc_size);

            immutable data = hibon.serialize;
            const doc = Document(data);

            assert(doc.length is 1);
            const e = doc[key];

            assert(e.type is Type.FLOAT32);
            Text key_text;
            assert(e.key(key_text) == key);
            assert(e.by!(Type.FLOAT32) == test_table[pos]);

        }


        { // HiBON Test for basic types
            auto hibon = HiBON();

            string[test_table.length] keys;
            foreach(i, t; test_table) {
                enum key = basename!(table.tupleof[i]);

                hibon[key] = t;
                keys[i]=key;
            }

            size_t index;
            foreach(m; hibon[]) {
                assert(m.key == keys[index]);
                index++;
            }

            foreach(i, t; test_table) {
                enum key = basename!(table.tupleof[i]);

                const m = hibon[key];
                assert(m.key == key);
                alias U=typeof(t);
                assert(m.get!(U) == t);
            }

            immutable data = hibon.serialize;
            const doc = Document(data);

            assert(doc.length is test_table.length);

            foreach(i, t; test_table) {
                enum key = basename!(table.tupleof[i]);
                const e = doc[key];
                Text key_text;
                assert(e.key(key_text) == key);
                alias U=typeof(t);
                assert(e.get!(U) == t);
            }
        }
    }


    unittest {
        struct TableArray {
            ubyte[] BINARY;
            // bool[]  BOOLEAN_ARRAY;
            // float[] FLOAT32_ARRAY;
            // double[]FLOAT64_ARRAY;
            // int[]   INT32_ARRAY;
            // long[]  INT64_ARRAY;
            char[]  STRING;
            // uint[]  UINT32_ARRAY;
            // ulong[] UINT64_ARRAY;


        }


        TableArray table_array;
        const(ubyte[3]) binary=[1, 2, 3];
        table_array.BINARY.create(binary);
        // const(float[3]) float32_array=[-1.23, 3, 20e30];
        // table_array.FLOAT32_ARRAY.create(float32_array);
        // const(double[2]) float64_array=[10.3e200, -1e-201];
        // table_array.FLOAT64_ARRAY.create(float64_array);
        // const(int[4]) int32_array=[-11, -22, 33, 44];
        // table_array.INT32_ARRAY.create(int32_array);
        // const(long[4]) int64_array=[0x17, 0xffff_aaaa, -1, 42];
        // table_array.INT64_ARRAY.create(int64_array);
        // const(uint[4]) uint32_array=[11, 22, 33, 44];
        // table_array.UINT32_ARRAY.create(uint32_array);
        // const(ulong[4]) uint64_array=[0x17, 0xffff_aaaa, 1, 42];
        // table_array.UINT64_ARRAY.create(uint64_array);
        // const(bool[2]) boolean_array=[true, false];
        // table_array.BOOLEAN_ARRAY.create(boolean_array);
        const(char[4]) text="Text";
        table_array.STRING.create(text);

        auto test_table_array=table_array.tupleof;
        scope(exit) {
            foreach(i, t; test_table_array) {
                .dispose(t);
            }
        }


        { // HiBON Test for basic-array types
            auto hibon = HiBON();

            string[test_table_array.length] keys;
            foreach(i, t; test_table_array) {
                enum key = basename!(table_array.tupleof[i]);
                hibon[key] = cast(immutable)t;
                keys[i]=key;
            }

            size_t index;
            foreach(m; hibon[]) {
                assert(m.key == keys[index]);
                index++;
            }

            foreach(i, t; test_table_array) {
                enum key = basename!(table_array.tupleof[i]);
                const m = hibon[key];
                assert(m.key == key);
                alias U=immutable(typeof(t));
                assert(m.get!(U) == t);
            }

            immutable data = hibon.serialize;
            const doc = Document(data);

            assert(doc.length is test_table_array.length);

            foreach(i, t; test_table_array) {
                enum key = basename!(table_array.tupleof[i]);
                const e = doc[key];
                Text key_text;
                assert(e.key(key_text) == key);
                alias U=immutable(typeof(t));
                assert(e.get!(U) == t);
            }

        }
    }

    unittest { // HIBON test containg an child HiBON
        auto hibon = HiBON();
        auto hibon_child = HiBON();
        enum child_name = "child";

        hibon["string"] = "Text";
        hibon["float"]  = float(1.24);

        immutable hibon_size_no_child = hibon.serialize_size;
        hibon_child["int32"]= 42;
        immutable hibon_child_size    = hibon_child.serialize_size;
        hibon[child_name]      = hibon_child;

        immutable child_key_size = Document.sizeKey(child_name);
        immutable hibon_size = hibon.serialize_size;
        assert(hibon_size is hibon_size_no_child+child_key_size+hibon_child_size);

        immutable data = hibon.serialize;

        assert(data.length is hibon_size);
        const doc = Document(data);

    }

    unittest { // Use of native Documet in HiBON
        auto native_hibon = HiBON();
        native_hibon["int"] = int(42);
        immutable native_data = native_hibon.serialize;
        auto native_doc = Document(native_hibon.serialize);

        auto hibon = HiBON();
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
            const sub_doc =  e.get!Document;
            assert(sub_doc.length is 1);
            assert(sub_doc.data == native_data);
            const sub_e = sub_doc["int"];
            assert(sub_e.type is Type.INT32);
            assert(sub_e.get!int is 42);
        }
    }

    unittest { // Document array
        import std.typecons : Tuple, isTuple;
        auto hibon_array=HiBON();
        alias TabelDocArray = Tuple!(
            int, "a",
            bool, "b",
            float, "c"
            );
        TabelDocArray tabel_doc_array;
        tabel_doc_array.a=42;
        tabel_doc_array.b=true;
        tabel_doc_array.c=42.42;

        foreach(i, t; tabel_doc_array) {
            enum name=tabel_doc_array.fieldNames[i];
            auto local_hibon=HiBON();
            local_hibon[name]=t;
            if ( i < 1) {
            hibon_array~=local_hibon;
            }
        }

        auto hibon = HiBON();
        hibon["int"]  = int(42);
        hibon["array"]= hibon_array;

        immutable data = hibon.serialize;

        const doc = Document(data);

        {
            assert(doc["int"].get!int is 42);
        }

    }
    unittest { // Check empty/null object
        {
            auto hibon=HiBON();
            auto sub=HiBON();
            assert(sub.size == ubyte.sizeof);
            const sub_doc=Document(sub.serialize);
            hibon["a"]=sub_doc;
            assert(hibon.size == Type.sizeof+ubyte.sizeof+"a".length+sub.size);

        }

        {
            auto hibon=HiBON();
            auto sub=HiBON();
            assert(sub.size == ubyte.sizeof);
            hibon["a"]=sub;
            assert(hibon.size == Type.sizeof+ubyte.sizeof+"a".length+sub.size);
        }
    }

}
