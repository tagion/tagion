module tagion.hibon.HiBONRecord;

@safe:
public import tagion.hibon.HiBONSerialize;

import std.exception : assumeWontThrow;
import std.stdio;
import std.traits;
import std.typecons : No, Tuple, Yes, Flag;
import tagion.basic.basic : EnumContinuousSequency, basename;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONBase : ValueT;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONJSON;
import std.algorithm;

alias DocResult = Tuple!(Document.Element.ErrorCode, "error", string, "key");

///  Returns: true if struct or class supports toHiBON
enum isHiBON(T) = (is(T == struct) || is(T == class)) && hasMember!(T,
            "toHiBON") && (is(ReturnType!(T.toHiBON) : const(HiBON)));

///  Returns: true if struct or class supports toDoc
enum isHiBONRecord(T) = (is(T == struct) || is(T == class)) && hasMember!(T,
            "toDoc") && (is(ReturnType!(T.toDoc) : const(Document)));

enum isHiBONTypeArray(T) = isArray!T && isHiBONRecord!(ForeachType!T);

/**
	Used for HiBONRecords which have a recorder type
	Params: 
        T = is the type of the recorder to be checked doc 
	Returns: 
        true if the doc has the correct Recorder type 
*/
bool isRecord(T)(const Document doc) nothrow pure {
    static if (hasUDA!(T, recordType)) {
        enum record_type = getUDAs!(T, recordType)[0].name;
        return doc.hasMember(TYPENAME) && assumeWontThrow(doc[TYPENAME] == record_type);
    }
    else {
        return false;
    }
}

/**
    Get the record type name set by @recordType("name")
*/
string recordName(const Document doc) nothrow pure {
    if (doc.hasMember(TYPENAME)) {
        return assumeWontThrow(doc[TYPENAME].get!string);
    }
    return string.init;
}

bool hasHashKey(T)(T doc) if (is(T : const(HiBON)) || is(T : const(Document))) {
    return !doc.empty && doc.keys.front[0] is HiBONPrefix.HASH && doc.keys.front != STUB;
}

unittest {
    import std.array : array;
    import std.range : iota;

    Document doc;
    { // Define stub
        auto h = new HiBON;
        h[STUB] = iota(ubyte(5)).array.idup;
        doc = Document(h);
    }

    assert(isStub(doc));
    assert(!hasHashKey(doc));

    { // Define document with hash key
        auto h = new HiBON;
        h["#key"] = "some data";
        doc = Document(h);
    }

    assert(!isStub(doc));
    assert(hasHashKey(doc));
}

template isSpecialKeyType(T) {
    import std.traits : KeyType, isAssociativeArray, isUnsigned;

    static if (isAssociativeArray!T) {
        alias KeyT = KeyType!T;
        enum isSpecialKeyType = !ValueT!(false, void, void).hasType!KeyT;
    }
    else {
        enum isSpecialKeyType = false;
    }
}

/++
 Label use to set the HiBON member name
 +/
struct label {
    string name; /// Name of the HiBON member
}

struct optional; /// This flag is set to true if this parameter is optional

struct exclude; // Exclude the member from the HiBONRecord
/++
 filter attribute for toHiBON
 +/
struct filter {
    string code; /// filter function
    enum Initialized = filter(q{a !is a.init});
}

/++
 Validates the Document type on construction
 +/
struct inspect {
    string code; ///
    enum Initialized = inspect(q{a !is a.init});
}

/++
 Used to set a member default value of the member is not defined in the Document
 +/
struct fixed {
    string code; /// This function is used to fix value
}

struct preserve; /// This preserve the size of array
/++
 Sets the HiBONRecord type
 +/
struct recordType {
    string name; /// Name of the HiBON record-type 
    string code; /// This is mixed after the Document constructor
}

struct disableCTOR;

struct disableSerialize;
enum isSerializeDisabled(T) = hasUDA!(T, disableSerialize);
/++
 Gets the label for HiBON member
 Params:
 member = is the member alias
 +/
template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;

    static if (hasUDA!(member, label)) {
        enum _label = getUDAs!(member, label)[0];
        enum GetLabel = _label;
    }
    else {
        enum GetLabel = label(basename!(member));
    }
}

mixin template HiBONRecordType() {
    import std.traits;
    import tagion.hibon.Document : Document;
    import tagion.hibon.HiBONRecord : TYPENAME, recordType;

    alias This = typeof(this);

    static if (hasUDA!(This, recordType)) {
        alias record_types = getUDAs!(This, recordType);
        static assert(record_types.length is 1, "Only one recordType UDA allowed");
        static if (record_types[0].name.length) {
            enum type_name = record_types[0].name;
            import tagion.hibon.HiBONRecord : isRecordT = isRecord;

            alias isRecord = isRecordT!This;
        }
    }

    /**
        Get the record type name set by @recordType("name")
    */
    static string recordName() @nogc pure nothrow {
        static if (hasMember!(This, "type_name")) {
            return type_name;
        }
        return string.init;
    }

}

mixin template HiBONKeys() {
    import std.traits;
    import std.functional : unaryFun;

    template GetKeyName(uint i) {
        static if (hasUDA!(this.tupleof[i], label)) {
            alias label = GetLabel!(this.tupleof[i]);
            enum GetKeyName = label.name;
        }
        else {
            enum GetKeyName = FieldNameTuple!This[i];
        }
    }

    template GetTupleIndex(string name, size_t index = 0) {
        static if (index == This.tupleof.length) {
            enum GetTupleIndex = -1;
        }
        else static if (name == GetKeyName!index) {
            enum GetTupleIndex = index;
        }
        else {
            enum GetTupleIndex = GetTupleIndex!(name, index + 1);
        }
    }
    /++
     Returns:
     A sorted list of Record keys
     +/
    protected static string[] _keys() pure nothrow {
        import std.algorithm;
        import tagion.hibon.HiBONBase : less_than;

        string[] result;
        static if (hasUDA!(This, recordType) && (getUDAs!(This, recordType)[0].name.length > 0)) {
            result ~= TYPENAME;
        }
        static foreach (i; 0 .. Fields!(This).length) {
            result ~= GetKeyName!i;
        }
        result.sort!((a, b) => less_than(a, b));

        return result;
    }

    enum keys = _keys;
}

/++
 HiBON Helper template to implement constructor and toHiBON member functions
 Params:
 TYPE = is used to set a HiBON record type (TYPENAME)
 Examples:
 --------------------
@recodeType("TEST") // Set the HiBONRecord type name
 struct Test {
 @label("$X") uint x;     // The member in HiBON is "$X"
 string name;             // The member in HiBON is "name"
 @label("num") int num;   // The member in HiBON is "num" and is optional
 @optional  string text;  // optional hibon member 
 @exclude bool dummy;   // This parameter is not included in the HiBON
 }
 --------------------
 CTOR = is used for constructor
 Example:
 --------------------
 struct TestCtor {
 uint x;
 HiBONRecord!("TEST2",
 q{
 this(uint x) {
 this.x=x;
 }
 }
 );
 }
 --------------------

 +/

pragma(msg, "fixme(cbr): The less_than function in this mixin is used for none string key (Should be added to the HiBON spec)");

mixin template HiBONRecord(string CTOR = "") {

    import std.traits;
    import std.algorithm : map, all;
    import std.array : array, assocArray, join;
    import std.format;
    import std.functional : unaryFun;
    import std.meta : AliasSeq;
    import std.range : enumerate, iota, lockstep;
    import std.range.primitives : isInputRange;
    import std.typecons;
    import tagion.basic.basic : EnumContinuousSequency, basename;

    //    import tagion.hibon.HiBONException : check;
    import tagion.basic.Message : message;
    import tagion.basic.basic : CastTo, basename;
    import tagion.errors.tagionexceptions : Check;
    import tagion.hibon.HiBONException;
    import tagion.hibon.HiBONRecord : isHiBON, isHiBONRecord, HiBONRecordType, HiBONKeys, isSpecialKeyType,
        label, exclude, optional, GetLabel, filter, fixed, inspect, preserve, isSerializeDisabled, disableCTOR;
    import tagion.hibon.HiBONBase : isKey, TypedefBase, is_index;
    import HiBONRecord = tagion.hibon.HiBONRecord;
    import tagion.hibon.HiBONSerialize;
    import tagion.basic.Debug;

    protected alias check = Check!(HiBONRecordException);

    import tagion.hibon.HiBON : HiBON;
    import tagion.hibon.HiBONJSON : JSONString;

    mixin JSONString;

    mixin HiBONRecordType;

    mixin Serialize;

    alias isRecord = HiBONRecord.isRecord!This;

    enum HAS_TYPE = hasMember!(This, "type_name");
    static bool less_than(Key)(Key a, Key b) if (!is(Key : string)) {
        alias BaseKey = TypedefBase!Key;
        static if (HiBON.Value.hasType!BaseKey || is(BaseKey == enum)) {
            return Key(a) < Key(b);
        }
        else static if (isHiBONRecord!BaseKey) {
            return a.toDoc.serialize < b.toDoc.serialize;
        }
        else {
            assert(0, format("Index %s is not supported", Index.stringof));
        }
    }

    @trusted final inout(HiBON) toHiBON() inout pure {
        auto hibon = new HiBON;
        static HiBON toList(bool preserve_flag = false, L)(L list) {
            import std.algorithm : sort;
            import std.algorithm.iteration : map;
            import std.array : array, byPair;
            import std.range : refRange;
            import std.typecons : tuple;

            auto result = new HiBON;
            alias UnqualL = Unqual!L;
            alias ElementT = Unqual!(TypedefBase!(ForeachType!L));
            //uint list_index;
            static if (isArray!L) {
                auto range = list;
                enum hibon_key = true;
            }
            else static if (isAssociativeArray!L) {
                auto range = list;
                alias KeyT = TypedefBase!(KeyType!L);
                enum hibon_key = isKey!KeyT;
            }
            else {
                auto range = list.enumerate;
                enum hibon_key = true;
            }

            static if (hibon_key) {
                static if (preserve_flag) {
                    size_t max_index;
                }
                foreach (index, e; range) {
                    void set(Index, Value)(Index key, Value value) {
                        if (!value.isinit) {
                            static if (preserve_flag) {
                                max_index = max(key, max_index);
                            }
                            result[key] = value;
                        }
                    }

                    static if (HiBON.Value.hasType!ElementT || is(ElementT == enum)) {
                        set(index, e);
                    }
                    else static if (isHiBON!ElementT) {
                        if (e !is e.init) {
                            set(index, e.toHiBON);
                        }
                    }
                    else static if (isPointer!ElementT) {
                        if (e !is null) {
                            set(index, e.toDoc);
                        }
                    }
                    else static if (isInputRange!ElementT) {
                        set(index, toList(e));
                    }
                    else {
                        static assert(0, format("Can not convert %s to HiBON", L.stringof));
                    }
                }
                static if (preserve_flag) {
                    if (max_index + 1 != range.length && range.length > 0) {
                        result[range.length - 1] = ForeachType!L.init;
                    }
                }
            }
            else {
                alias HiBONOrder = Tuple!(HiBON, "hibon", Document, "doc");
                HiBONOrder[] order_list;
                foreach (key, value; range) {
                    auto h = new HiBON;
                    h[0] = key;
                    h[1] = value;
                    order_list ~= HiBONOrder(h, Document(h.serialize));
                }
                order_list.sort!((a, b) => a.doc.data < b.doc.data);
                result = order_list.map!(order => order.hibon);
            }
            return result;
        }

        MemberLoop: foreach (i, m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                alias MemberT = typeof(m);
                alias BaseT = TypedefBase!MemberT;
                alias UnqualT = Unqual!BaseT;
                enum default_name = FieldNameTuple!This[i];
                enum optional_flag = hasUDA!(this.tupleof[i], optional);
                enum exclude_flag = hasUDA!(this.tupleof[i], exclude);
                enum filter_flag = hasUDA!(this.tupleof[i], filter);
                enum preserve_flag = hasUDA!(this.tupleof[i], preserve) && isArray!UnqualT;
                alias label = GetLabel!(this.tupleof[i]);
                enum name = label.name;
                static if (filter_flag) {
                    alias filters = getUDAs!(this.tupleof[i], filter);
                    static foreach (F; filters) {
                        {
                            alias filterFun = unaryFun!(F.code);
                            if (!filterFun(this.tupleof[i])) {
                                continue MemberLoop;
                            }
                        }
                    }
                }
                static if (optional_flag) {
                    alias filterFun = unaryFun!(filter.Initialized.code);
                    if (!filterFun(this.tupleof[i])) {
                        continue MemberLoop;
                    }
                }
                static assert(name.length > 0,
                        format("Label for %s can not be empty", default_name));
                static if (!exclude_flag) {
                    static if (HiBON.Value.hasType!UnqualT) {
                        hibon[name] = ((x) @trusted => cast(BaseT) x)(m);
                    }
                    else static if (isHiBON!BaseT) {
                        hibon[name] = m.toHiBON;
                    }
                    else static if (isHiBONRecord!BaseT) {
                        hibon[name] = m.toDoc;
                    }
                    else static if (is(MemberT == enum)) {
                        hibon[name] = cast(OriginalType!MemberT) m;
                    }
                    else static if (is(BaseT == class) || is(BaseT == struct)) {
                        static if (isInputRange!UnqualT) {
                            alias ElementT = Unqual!(ForeachType!UnqualT);
                            static assert((HiBON.Value.hasType!ElementT) || isHiBON!ElementT,
                                    format("The sub element '%s' of type %s is not supported",
                                    name, BaseT.stringof));

                            hibon[name] = toList(cast(UnqualT) m);
                        }
                        else {
                            static assert(is(BaseT == HiBON) || is(BaseT : const(Document)),
                                    format(`A sub class/struct '%s' of type %s must have"~
                            " a toHiBON or must be ignored with @exclude UDA tag`,
                                    name, BaseT.stringof));
                            hibon[name] = cast(BaseT) m;
                        }
                    }
                    else static if (isPointer!BaseT) {
                        hibon[name] = m.toDoc;
                    }
                    else static if (isInputRange!UnqualT || isAssociativeArray!UnqualT) {
                        alias BaseU = TypedefBase!(ForeachType!(UnqualT));
                        hibon[name] = toList!preserve_flag(m);
                    }
                    else static if (isIntegral!UnqualT || UnqualT.sizeof <= short.sizeof) {
                        static if (isUnsigned!UnqualT) {
                            hibon[name] = cast(uint) m;
                        }
                        else {
                            hibon[name] = cast(int) m;
                        }
                    }
                    else {
                        static assert(0, format(
                                "converting for member '%s' of type" ~
                                " %s is not supported by default",
                                name, MemberT.stringof));
                    }
                }
            }
        }
        static if (HAS_TYPE) {
            hibon[TYPENAME] = type_name;
        }
        @nogc @trusted inout(HiBON) result() inout pure nothrow {
            return cast(inout) hibon;
        }

        return result;
    }

    enum NO_DEFAULT_CTOR = (CTOR == "{}");
    /++
     Constructors must be mixed in or else the default construction is will be removed
     +/
    static if (CTOR.length && !NO_DEFAULT_CTOR) {
        mixin(CTOR);
    }

    mixin HiBONKeys;
    static if (!NO_DEFAULT_CTOR) {
        @safe this(const HiBON hibon) pure {
            this(Document(hibon.serialize));
        }

        static if (CTOR.length is 0 && !hasUDA!(This, disableCTOR)) {
            this(inout Fields!This args) pure nothrow inout {

                this.tupleof = args;
            }
        }
        @safe this(const Document doc) pure {
            static if (HAS_TYPE) {
                Check!HiBONRecordTypeException(doc.hasMember(TYPENAME), "Missing HiBON type");
                string _type = doc[TYPENAME].get!string;
                Check!HiBONRecordTypeException(_type == type_name,
                        format("Wrong %s type %s should be %s",
                        TYPENAME, _type, type_name));
            }
            else {
                enum type_name = "";
            }
            static if (hasUDA!(This, recordType)) {
                enum record = getUDAs!(This, recordType)[0];
                static if (record.code) {
                    scope (exit) {
                        mixin(record.code);
                    }
                }
            }
            static R toList(R)(const Document doc) {
                import core.lifetime : copyEmplace;

                alias MemberU = ForeachType!(R);
                alias BaseU = TypedefBase!MemberU;
                static if (isArray!R) {
                    alias UnqualU = Unqual!MemberU;
                    MemberU[] result;
                    if (doc.isArray) {
                        result = doc[].map!(e => e.get!MemberU).array;
                    }
                    else {
                        uint index;
                        const is_indices = doc.keys.all!((key) => is_index(key, index));
                        check(is_indices, format("Document is expected to be an array"));
                        result.length = index + 1;
                        foreach (e; doc[]) {
                            is_index(e.key, index);
                            MemberU elm = e.get!MemberU;
                            (() @trusted => copyEmplace(elm, result[index]))();
                        }
                    }
                    enum do_foreach = false;
                }
                else static if (isSpecialKeyType!R) {
                    R result;
                    enum do_foreach = true;
                }
                else static if (isAssociativeArray!R) {
                    alias ValueT = ForeachType!R;
                    alias KeyT = KeyType!R;
                    static if (isKey!KeyT) {
                        R result = assocArray(
                                doc.keys.map!(key => key.to!KeyT),
                                doc[].map!(e => e.get!ValueT));
                    }
                    else {
                        auto pairs = doc[]
                            .map!(e => e.get!Document)
                            .map!(pair => tuple(pair[0].get!KeyT, pair[1].get!ValueT));
                        R result = assocArray(pairs);
                    }
                    enum do_foreach = false;

                }
                else {
                    return R(doc);
                    enum do_foreach = false;
                }
                static if (do_foreach) {
                    foreach (elm; doc[]) {
                        static if (isSpecialKeyType!R) {
                            const value_doc = elm.get!Document;
                            alias KeyT = KeyType!R;
                            alias BaseKeyT = TypedefBase!KeyT;
                            static if (Document.Value.hasType!BaseKeyT || is(BaseKeyT == enum)) {
                                const key = KeyT(value_doc[0].get!BaseKeyT);
                            }
                            else {
                                auto key = KeyT(value_doc[0].get!BaseKeyT);
                            }
                            const e = value_doc[1];
                        }
                        else {
                            const e = elm;
                        }
                        static if (Document.Value.hasType!MemberU || is(BaseU == enum)) {
                            auto value = e.get!BaseU;
                        }
                        else static if (Document.Value.hasType!BaseU) {
                            // Special case for Typedef
                            auto value = MemberU(e.get!BaseU);
                        }
                        else {
                            const sub_doc = e.get!Document;
                            static if (is(BaseU == struct)) {
                                auto value = BaseU(sub_doc);
                            }
                            else static if (is(BaseU == class)) {
                                auto value = new BaseU(sub_doc);
                            }
                            else static if (isInputRange!BaseU) {
                                auto value = toList!BaseU(sub_doc);
                            }
                            else {
                                static assert(0,
                                        format("Can not convert %s to Document", R.stringof));
                            }
                        }
                        static if (isAssociativeArray!R) {
                            static if (isSpecialKeyType!R) {
                                result[key] = value;
                            }
                            else {
                                alias ResultKeyType = KeyType!(typeof(result));
                                result[e.key.to!ResultKeyType] = value;
                            }
                        }
                        else {
                            result[e.index] = value;
                        }
                    }
                }
                return result;
            }

            enum do_valid = hasMember!(This, "valid")
                && isCallable!(valid) && __traits(compiles, valid(doc));
            static if (do_valid) {
                check(valid(doc),
                        format("Document verification failed for HiBONRecord %s",
                        This.stringof));
            }

            enum do_verify = hasMember!(This, "verify") && isCallable!(verify); // && __traits(compiles, this.verify());

            static if (do_verify) {
                static assert(__traits(compiles, this.verify()),
                        format("%s.verify() should be const pure nothrow", This.stringof));
                scope (exit) {
                    check(this.verify(),
                            format("Document verification failed for HiBONRecord %s",
                            This.stringof));
                }
            }

            ForeachTuple: foreach (i, ref m; this.tupleof) {
                static if (__traits(compiles, typeof(m))) {
                    enum default_name = FieldNameTuple!This[i];
                    enum optional_flag = hasUDA!(this.tupleof[i], optional);
                    enum exclude_flag = hasUDA!(this.tupleof[i], exclude);
                    enum preserve_flag = hasUDA!(this.tupleof[i], preserve);
                    static if (hasUDA!(this.tupleof[i], label)) {
                        alias label = GetLabel!(this.tupleof[i]);
                        enum name = label.name;
                        static if (optional_flag) {
                            if (!doc.hasMember(name)) {
                                continue ForeachTuple;
                            }
                        }
                        static if (HAS_TYPE) {
                            static assert(TYPENAME != label.name,
                                    format("Fixed %s is already defined to %s" ~
                                    " but is redefined for %s.%s",
                                    TYPENAME, TYPE, This.stringof,
                                    basename!(this.tupleof[i])));
                        }
                    }
                else {
                        enum name = default_name;
                    }
                    static assert(name.length > 0,
                            format("Label for %s can not be empty", default_name));
                    static if (!exclude_flag) {
                        static if (hasUDA!(this.tupleof[i], fixed)) {
                            alias assigns = getUDAs!(this.tupleof[i], fixed);
                            static assert(assigns.length is 1,
                                    "Only one fixed UDA allowed per member");
                            static assert(!optional_flag,
                                    "The optional parameter in label can not" ~
                                    " be used in connection with the fixed attribute");

                            enum code = format(q{this.tupleof[i]=%s;}, assigns[0].code);
                            if (!doc.hasMember(name)) {
                                mixin(code);
                                continue ForeachTuple;
                            }
                        }
                        alias MemberT = typeof(m);
                        alias BaseT = MemberT;
                        alias UnqualT = Unqual!BaseT;
                        const has_member = doc.hasMember(name);
                        static if (optional_flag) {
                            if (!has_member) {
                                continue ForeachTuple;
                            }
                        }
                        else {
                            Check!(HiBONRecordException)(has_member,
                                    format("Member '%s' not found in Document %s", name, type_name));
                        }
                        static if (hasUDA!(this.tupleof[i], inspect)) {
                            alias Inspects = getUDAs!(this.tupleof[i], inspect);
                            scope (exit) {
                                static foreach (F; Inspects) {
                                    {
                                        alias inspectFun = unaryFun!(F.code);
                                        check(inspectFun(m),
                                                format("Member %s failed on inspection %s with %s",
                                                name, F.code, m));
                                    }
                                }
                            }

                        }
                        static if (is(BaseT == enum)) {
                            m = doc[name].get!BaseT;
                        }
                        else static if (Document.isDocTypedef!BaseT) {
                            m = doc[name].get!BaseT;
                        }
                        else static if (Document.Value.hasType!BaseT) {
                            m = doc[name].get!BaseT;
                        }
                        else static if (is(BaseT == struct)) {
                            auto sub_doc = doc[name].get!Document;
                            m = BaseT(sub_doc);
                        }
                        else static if (is(BaseT == class)) {
                            const sub_doc = Document(doc[name].get!Document);
                            m = new BaseT(sub_doc);
                        }
                        else static if (isPointer!BaseT) {
                            const sub_doc = Document(doc[name].get!Document);
                            m = new PointerTarget!BaseT(sub_doc);
                        }
                        else static if (isInputRange!BaseT || isAssociativeArray!BaseT) {
                            Document sub_doc;
                            if (doc.hasMember(name)) {
                                sub_doc = Document(doc[name].get!Document);
                            }
                            m = toList!BaseT(sub_doc);
                        }
                        else static if (isIntegral!BaseT && BaseT.sizeof <= short.sizeof) {
                            static if (isUnsigned!BaseT) {
                                m = cast(BaseT) doc[name].get!uint;
                            }
                            else {
                                m = cast(BaseT) doc[name].get!int;
                            }
                        }
                        else {
                            static assert(0,
                                    format("Converting for member '%s' of type %s" ~
                                    " is not supported by default",
                                    name, MemberT.stringof));

                        }
                    }
                }
                else {
                    static assert(0, format("Type %s for member %s is not supported",
                            BaseT.stringof, name));
                }
            }
        }
    }

    static if (isSerializeDisabled!This) {
        @safe final immutable(ubyte[]) serialize() const pure {
            return toHiBON.serialize;
        }
    }

    @safe final const(Document) toDoc() const pure {
        return Document(serialize);
    }
}

version (unittest) {
    void check_serialize(T)(T s, const Document docS) {
        const s_serialize = s.serialize;
        const h = s.toHiBON;
        const hibon_serialize = h.serialize;
        static if (SupportingFullSizeFunction!T) {
            assert(docS.full_size == s.full_size);
        }
        assert(docS.full_size == s_serialize.length);
        assert(hibon_serialize.length == s_serialize.length);

        assert(hibon_serialize == s_serialize);
    }
}

unittest {
    import std.algorithm;
    import std.exception : assertNotThrown, assertThrown;
    import std.format;
    import std.meta : AliasSeq;
    import std.range;
    import std.stdio;
    import std.traits : OriginalType, Unqual;
    import tagion.hibon.HiBONException : HiBONException, HiBONRecordException;

    @recordType("SIMPLE")
    static struct Simple {
        int s;
        string text;
        mixin HiBONRecord!(q{
                this(int s, string text) pure {
                    this.s=s; this.text=text;
                }
            });
    }

    { /// Should fail on empty document
        /// Simple HiBON test
        {
            //    create_empty;
            assertThrown!(HiBONRecordTypeException)(
            { const simple_type = Simple(Document()); }(),
                    "Should throw because empty_doc is missing a hibon-record-type");
        }
        {
            auto h = new HiBON;
            h[TYPENAME] = "NotASimpleType";
            const doc = Document(h);
            assertThrown!(HiBONRecordTypeException)(
            { const simple_type = Simple(doc); }(),
                    "Should throw because the HiBON record type is not correct");
            //const simple_type=Simple(doc);
        }
        {
            auto h = new HiBON;
            h[TYPENAME] = Simple.type_name;
            const doc = Document(h);
            assertThrown!(HiBONException)(
            { const simple_type = Simple(doc); }(),
                    "Should throw because the HiBON the document does not contain any members");
        }

        {

            Simple s;
            const s_doc = s.toDoc;
            const s_result = assertNotThrown!(Exception)(Simple(s_doc),
                    "Should not throw any exceptions");
            assert(s == s_result);
        }

    }

    static assert(equal(Simple.keys, only(TYPENAME, "s", "text")));
    static assert(Simple.GetTupleIndex!"s" == 0);
    static assert(Simple.GetTupleIndex!"text" == 1);
    static assert(Simple.GetTupleIndex!"not defined" == -1);

    @recordType("SIMPLELABEL")
    static struct SimpleLabel {
        @label("TEXT") string text;
        @label("$S") int s;
        mixin HiBONRecord!(q{
                this(int s, string text) pure {
                    this.s=s; this.text=text;
                }
            });
    }

    static assert(equal(SimpleLabel.keys, only(TYPENAME, "$S", "TEXT")));

    static assert(SimpleLabel.GetTupleIndex!"$S" == 1);
    static assert(SimpleLabel.GetTupleIndex!"TEXT" == 0);
    static assert(SimpleLabel.GetTupleIndex!"not defined" == -1);

    @recordType("BASIC")
    static struct BasicData {
        int i32;
        uint u32;
        long i64;
        ulong u64;
        float f32;
        double f64;
        string text;
        bool flag;
        mixin HiBONRecord!(q{this(int i32,
                    uint u32,
                    long i64,
                    ulong u64,
                    float f32,
                    double f64,
                    string text,
                    bool flag) {
                    this.i32=i32;
                    this.u32=u32;
                    this.i64=i64;
                    this.u64=u64;
                    this.f32=f32;
                    this.f64=f64;
                    this.text=text;
                    this.flag=flag;
                }
            });
    }

    template SimpleOption(string LABEL = "") {
        @recordType(LABEL)
        static struct SimpleOption {
            int not_an_option;
            @label("s") @optional int s;
            @optional string text;
            mixin HiBONRecord!();
        }
    }

    { // Simple basic type check
    {
            const s = Simple(-42, "some text");
            const docS = s.toDoc;
            // writefln("keys=%s", docS.keys);
            assert(docS["s"].get!int == -42);
            assert(docS["text"].get!string == "some text");
            assert(docS[TYPENAME].get!string == Simple.type_name);
            assert(isRecord!Simple(docS));
            const s_check = Simple(docS);
            // const s_check=Simple(s);
            assert(s == s_check);
            assert(s_check.toJSON.toString == format("%j", s_check));

            assert(isRecord!Simple(docS));
            assert(!isRecord!SimpleLabel(docS));
            assert(docS.full_size == s.full_size);
            check_serialize(s, docS);
        }

        {
            const s = SimpleLabel(42, "other text");
            const docS = s.toDoc;
            assert(docS["$S"].get!int == 42);
            assert(docS["TEXT"].get!string == "other text");
            assert(docS[TYPENAME].get!string == SimpleLabel.type_name);
            assert(isRecord!SimpleLabel(docS));
            const s_check = SimpleLabel(docS);

            assert(s == s_check);
            immutable s_imut = SimpleLabel(docS);
            assert(s_imut == s_check);
            check_serialize(s, docS);
        }

        {
            const s = BasicData(-42, 42, -42_000_000_000UL, 42_000_000_000L,
                    42.42e-9, -42.42e-300, "text", true);
            const docS = s.toDoc;

            const s_check = BasicData(docS);
            assert(s == s_check);
            immutable s_imut = BasicData(docS);
            assert(s_imut == s_check);
            check_serialize(s, docS);
        }
    }

    { // Check option
        alias NoLabel = SimpleOption!("");
        alias WithLabel = SimpleOption!("LBL");

        { // Empty document
            auto h = new HiBON;
            const doc = Document(h.serialize);
            //            writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertThrown!HiBONException(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));
        }

        {
            auto h = new HiBON;
            h["not_an_option"] = 42;
            const doc = Document(h.serialize);
            //          writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!Exception(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));
        }

        {
            auto h = new HiBON;
            h["not_an_option"] = 42;
            h[TYPENAME] = "LBL";
            const doc = Document(h.serialize);
            //  writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!Exception(NoLabel(doc));
            assertNotThrown!Exception(WithLabel(doc));
        }

        {
            NoLabel s;
            s.not_an_option = 42;
            s.s = 17;
            s.text = "text!";
            const s_serialize = s.serialize;
            const s_hibon = s.toHiBON;
            const s_hibon_serialize = s_hibon.serialize;
            // writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assert(s_serialize == s_hibon_serialize);
            const doc = s.toDoc;
            assertNotThrown!Exception(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));

            auto h = s.toHiBON;
            h[TYPENAME] = WithLabel.type_name;
            const doc_label = Document(h.serialize);
            // writefln("docS=\n%s", doc_label.toJSON(true).toPrettyString);

            const s_label = WithLabel(doc_label);
            // writefln("docS=\n%s", s_label.toDoc.toJSON(true).toPrettyString);

            const s_new = NoLabel(s_label.toDoc);
        }
    }

    { // Check verify member
        template NotBoth(bool FILTER) {
            @recordType("NotBoth")
            static struct NotBoth {
                static if (FILTER) {
                    @optional @(filter.Initialized) int x;
                    @optional @(filter.Initialized) @filter(q{a < 42}) int y;
                }
                else {
                    @optional int x;
                    @optional int y;
                }
                bool valid(const Document doc) const pure nothrow {
                    return doc.hasMember("x") ^ doc.hasMember("y");
                }

                mixin HiBONRecord!(q{
                        this(int x, int y) {
                            this.x=x; this.y=y;
                        }
                    });
            }
        }

        alias NotBothFilter = NotBoth!true;
        alias NotBothNoFilter = NotBoth!false;

        const s_filter_x = NotBothFilter(11, int.init);
        const s_filter_y = NotBothFilter(int.init, 13);
        const s_dont_filter = NotBothFilter();
        const s_dont_filter_xy = NotBothFilter(11, 13);

        const s_filter_x_doc = s_filter_x.toDoc;
        const s_filter_y_doc = s_filter_y.toDoc;
        const s_dont_filter_doc = s_dont_filter.toDoc;
        const s_dont_filter_xy_doc = s_dont_filter_xy.toDoc;
        assert(s_filter_x_doc.full_size == s_filter_x.full_size);
        assert(s_filter_y_doc.full_size == s_filter_y.full_size);
        assert(s_dont_filter_doc.full_size == s_dont_filter.full_size);
        assert(s_dont_filter_xy_doc.full_size == s_dont_filter_xy.full_size);

        const s_filter_x_serialize = s_filter_x.serialize;
        const s_filter_x_hibon_serialize = s_filter_x.toHiBON.serialize;
        assert(s_filter_x_serialize == s_filter_x_hibon_serialize);

        const s_filter_y_serialize = s_filter_y.serialize;
        const s_filter_y_hibon_serialize = s_filter_y.toHiBON.serialize;
        assert(s_filter_y_serialize == s_filter_y_hibon_serialize);

        const s_dont_filter_serialize = s_dont_filter.serialize;
        const s_dont_filter_hibon_serialize = s_dont_filter.toHiBON.serialize;
        assert(s_dont_filter_serialize == s_dont_filter_hibon_serialize);

        const s_dont_filter_xy_serialize = s_dont_filter_xy.serialize;
        const s_dont_filter_xy_hibon_serialize = s_dont_filter_xy.toHiBON.serialize;
        assert(s_dont_filter_xy_serialize == s_dont_filter_xy_hibon_serialize);
        {
            const check_s_filter_x = NotBothFilter(s_filter_x_doc);
            assert(check_s_filter_x == s_filter_x);
            const check_s_filter_y = NotBothFilter(s_filter_y_doc);
            assert(check_s_filter_y == s_filter_y);
        }

        { // Test that  the .verify throws an HiBONRecordException

            assertThrown!HiBONRecordException(NotBothNoFilter(s_dont_filter_doc));
            assertThrown!HiBONRecordException(NotBothNoFilter(s_dont_filter_xy_doc));
            assertThrown!HiBONRecordException(NotBothFilter(s_dont_filter_doc));
            assertThrown!HiBONRecordException(NotBothFilter(s_dont_filter_xy_doc));
        }

        {
            const s_filter_42 = NotBothFilter(12, 42);
            const s_filter_42_doc = s_filter_42.toDoc;
            const s_filter_not_42 = NotBothFilter(s_filter_42_doc);
            assert(s_filter_not_42 == NotBothFilter(12, int.init));
        }
    }

    {
        @safe static struct SuperStruct {
            Simple sub;
            string some_text;
            mixin HiBONRecord!(q{
                    this(string some_text, int s, string text) pure nothrow {
                        this.some_text=some_text;
                        sub=Simple(s, text);
                    }
                });
        }

        const s = SuperStruct("some_text", 42, "text");
        const doc = s.toDoc;
        const s_converted = SuperStruct(doc);
        assert(s == s_converted);
        assert(doc.toJSON.toString == format("%j", s_converted));
        assert(doc.toJSON.toPrettyString == format("%J", s_converted));
        check_serialize(s, doc);
    }

    {
        @safe static class SuperClass {
            Simple sub;
            string class_some_text;
            mixin HiBONRecord!(q{
                    this(string some_text, int s, string text) pure nothrow {
                        this.class_some_text=some_text;
                        sub=Simple(s, text);
                    }
                });
        }

        const s = new SuperClass("some_text", 42, "text");
        const doc = s.toDoc;
        const s_converted = new SuperClass(doc);
        assert(doc == s_converted.toDoc);
        assert(s.full_size == doc.full_size);

        // For some reason SuperClass because is a class format is not @safe
        (() @trusted {
            assert(doc.toJSON.toString == format("%j", s_converted));
            assert(doc.toJSON.toPrettyString == format("%J", s_converted));
        })();
        check_serialize(s, doc);
    }

    {
        static struct Test {
            @inspect(q{a < 42}) @inspect(q{a > 3}) int x;
            mixin HiBONRecord;
        }

        Test s;
        s.x = 17;
        assertNotThrown!Exception(Test(s.toDoc));
        s.x = 42;
        assertThrown!HiBONRecordException(Test(s.toDoc));
        s.x = 1;
        assertThrown!HiBONRecordException(Test(s.toDoc));

    }

    { // Base type array
        static struct Array {
            @label("i32_a") int[] a;
            mixin HiBONRecord;
        }

        Array s;
        {
            s.a = [-17, 42, 17];

            const doc = s.toDoc;
            const result = Array(doc);
            assert(s == result);
            assert(doc.toJSON.toString == format("%j", result));

            check_serialize(s, doc);
        }

        {
            s.a = [17, int.init, 42];

            const doc = s.toDoc;
            const result = Array(doc);
            assert(s == result);
            assert(doc.toJSON.toString == format("%j", result));
            check_serialize(s, doc);
        }

    }

    { // Array of HiBON
        static struct SimpleElement {
            int x;
            mixin HiBONRecord;
        }

        static struct TestArray {
            SimpleElement[] tests;
            mixin HiBONRecord;
        }

        { // Array should fail if tests is empty
            const empty_doc = Document();
            //const test_array = 
            assertThrown!(HiBONRecordException)(TestArray(empty_doc));
            {
                TestArray test_array;
                test_array.tests.length = 3;
                const test_array_serialize = test_array.serialize;
                const test_array_hibon_serialize = test_array.toHiBON.serialize;
                assert(test_array_serialize == test_array_hibon_serialize);

                const doc = test_array.toDoc;
                const test_array_result = TestArray(doc);
                assert(test_array_result.tests != test_array.tests);
                assert(test_array_result != test_array);

            }
        }
        static struct TestArrayPreserve {
            @preserve SimpleElement[] tests;
            mixin HiBONRecord;
        }

        {
            TestArrayPreserve test_array;
            test_array.tests.length = 3;
            const doc = test_array.toDoc;
            const test_array_serialize = test_array.serialize;
            const test_array_hibon = test_array.toHiBON;
            const test_array_hibon_serialize = test_array_hibon.serialize;
            assert(test_array_serialize == test_array_hibon_serialize);
            const test_array_result = TestArrayPreserve(doc);
            //const test_array_hibon=test_array.toHiBON;
            assert(test_array_result.tests == test_array.tests);
            assert(test_array_result == test_array);

        }
    }

    { // String array
        static struct StringArray {
            string[] texts;
            mixin HiBONRecord;
        }

        StringArray s;
        s.texts = ["one", "two", "three"];

        const doc = s.toDoc;
        const result = StringArray(doc);
        assert(s == result);
        assert(doc.toJSON.toString == format("%j", result));
        check_serialize(s, doc);
    }

    { // Element as range
        @safe static struct Range(T) {
            import std.array : to_array = array;

            alias UnqualT = Unqual!T;
            protected T[] array;
            @nogc this(T[] array) {
                this.array = array;
            }

            @nogc @property nothrow {
                const(T) front() const pure {
                    return array[0];
                }

                bool empty() const pure {
                    return array.length is 0;
                }

                void popFront() {
                    if (array.length) {
                        array = array[1 .. $];
                    }
                }
            }

            @trusted this(const Document doc) pure {
                array = doc[].map!(e => e.get!T).to_array;
            }
        }

        @safe auto structWithRangeTest(T)(T[] array) {
            alias R = Range!T;
            @safe static struct StructWithRange {
                R range;
                static assert(isInputRange!R);
                mixin HiBONRecord!(q{
                        this(T[] array) {
                            this.range=R(array);
                        }
                    });
            }

            return StructWithRange(array);
        }

        { // Simple Range
            const(int)[] array = [-42, 3, 17];
            const s = structWithRangeTest(array);

            const doc = s.toDoc;
            alias ResultT = typeof(s);

            const s_doc = ResultT(doc);

            assert(s_doc == s);
            assert(doc.toJSON.toString == format("%j", s));
            check_serialize(s, doc);
        }

        { // Range of structs
            Simple[] simpels;
            simpels ~= Simple(1, "one");
            simpels ~= Simple(2, "two");
            simpels ~= Simple(3, "three");
            {
                auto s = structWithRangeTest(simpels);
                alias StructWithRange = typeof(s);
                {
                    auto h = new HiBON;
                    h["s"] = s;

                    const s_get = h["s"].get!StructWithRange;
                    const doc_s_get = s_get.toDoc;
                    assert(s == s_get);
                    check_serialize(s, doc_s_get);
                }
            }

            {
                static struct SimpleArray {
                    Simple[] array;
                    mixin HiBONRecord;
                }

                { // SimpleArray with empty array
                    SimpleArray s;
                    auto h = new HiBON;
                    h["s"] = s;
                    const s_get = h["s"].get!SimpleArray;
                    assert(s_get == s);
                }
                {
                    SimpleArray s;
                    s.array = simpels;
                    auto h = new HiBON;
                    h["s"] = s;

                    const s_get = h["s"].get!SimpleArray;

                    assert(s_get == s);
                    const s_doc = s_get.toDoc;

                    const s_array = s_doc["array"].get!(Simple[]);
                    assert(equal(s_array, s.array));

                    const s_result = SimpleArray(s_doc);
                    assert(s_result == s);
                    check_serialize(s, s_doc);
                }
            }
        }

        { // Jagged Array
            @safe static struct Jagged {
                Simple[][] y;
                mixin HiBONRecord;
            }

            Simple[][] ragged = [
                [Simple(1, "one"), Simple(2, "one")],
                [Simple(1, "two"), Simple(2, "two"), Simple(3, "two")],
                [Simple(1, "three")]
            ];
            Jagged jagged;
            jagged.y = ragged;

            const jagged_doc = jagged.toDoc;

            const result = Jagged(jagged_doc);

            assert(jagged == result);

            assert(jagged_doc.toJSON.toString == format("%j", jagged));
            check_serialize(jagged, jagged_doc);
        }

        {
            @safe static struct Associative {
                Simple[string] a;
                mixin HiBONRecord;
            }

            Associative associative;
            associative.a["$one"] = Simple(1, "one");
            associative.a["$two"] = Simple(1, "two");
            associative.a["$three"] = Simple(1, "three");

            // writefln("%J", associative);

            const associative_doc = associative.toDoc;

            const result = Associative(associative_doc);
            (() @trusted {
                assert(equal(result.a.keys, associative.a.keys));
                assert(equal(result.a.byValue, associative.a.byValue));
            })();

            assert(associative_doc.toJSON.toString == format("%j", associative));
            check_serialize(associative, associative_doc);
        }

        { // Test of enum
            enum Count : uint {
                one = 1,
                two,
                three
            }

            { // Single enum
                static struct CountStruct {
                    Count count;
                    mixin HiBONRecord;
                }

                CountStruct s;
                s.count = Count.two;

                const s_doc = s.toDoc;
                const result = CountStruct(s_doc);

                assert(s == result);
                assert(s_doc.toJSON.toString == format("%j", result));
                check_serialize(s, s_doc);
            }

            { // Array of enum
                static struct CountArray {
                    Count[] count;
                    mixin HiBONRecord;
                }

                CountArray s;
                s.count = [Count.one, Count.two, Count.three];

                const s_doc = s.toDoc;
                const result = CountArray(s_doc);

                assert(s == result);
                assert(s_doc.toJSON.toString == format("%j", result));
                check_serialize(s, s_doc);
            }
        }

        { // Test of Typedef array
            import std.typecons : Typedef;

            alias Text = Typedef!(string, null, "Text");

            // Pubkey is a Typedef
            import tagion.crypto.Types : Pubkey;

            static struct TextArray {
                Text[] texts;
                mixin HiBONRecord;
            }

            TextArray s;
            s.texts = [Text("one"), Text("two"), Text("three")];

            const s_doc = s.toDoc;
            const result = TextArray(s_doc);

            assert(s == result);
            assert(s_doc.toJSON.toString == format("%j", result));
            check_serialize(s, s_doc);
        }

    }

    { // None standard Keys
        import std.algorithm : each, map;
        import std.algorithm : sort;
        import std.algorithm.sorting : isStrictlyMonotonic;
        import std.array : array;
        import std.range : tee;
        import std.stdio;
        import std.typecons : Typedef;
        import std.typecons : tuple;
        import tagion.basic.Types : Buffer;

        static void binwrite(Args...)(ubyte[] buf, Args args) @trusted {
            import std.bitmanip : write;

            write(buf, args);
        }

        { // Typedef on HiBON.type is used as key in an associative-array
            alias Bytes = Typedef!(immutable(ubyte)[], null, "Bytes");
            alias Table = int[Bytes];
            static struct StructBytes {
                Table table;
                mixin HiBONRecord;
            }

            static assert(isSpecialKeyType!Table);

            import std.outbuffer;

            Table table;
            auto list = [-17, 117, 3, 17, 42];
            auto buffer = new ubyte[int.sizeof];
            foreach (i; list) {
                binwrite(buffer, i, 0);
                table[Bytes(buffer.idup)] = i;
            }

            StructBytes s;
            s.table = table;
            const s_doc = s.toDoc;
            const result = StructBytes(s_doc);
            assert(s_doc == result.toDoc);
            check_serialize(s, s_doc);
        }

        { // Typedef of a HiBONRecord is used as key in an associative-array
            static struct KeyStruct {
                string text;
                int x;
                mixin HiBONRecord!(q{
                        this(int x, string text) {
                            this.x=x; this.text=text;
                        }
                    });
            }

            alias Key = Typedef!(KeyStruct, KeyStruct.init, "Key");

            alias Table = int[Key];

            static struct StructKeys {
                Table table;
                mixin HiBONRecord;
            }

            Table list = [
                Key(KeyStruct(2, "two")): 2, Key(KeyStruct(4, "four")): 4,
                Key(KeyStruct(1, "one")): 1, Key(KeyStruct(3, "three")): 3
            ];

            StructKeys s;
            s.table = list;

            const s_doc = s.toDoc;

            // Checks that the key is ordered in the table
            assert(s_doc["table"].get!Document[].map!(
                    a => a.get!Document[0].get!Document.serialize).array.isStrictlyMonotonic);

            const result = StructKeys(s_doc);
            assert(result.toDoc == s.toDoc);
            check_serialize(s, s_doc);
        }
    }

    { // Fixed Attribute
        // The fixed atttibute is used set a default i value in case the member was not defined in the Document
        static struct FixedStruct {
            @label("$x") @filter(q{a != 17}) @fixed(q{-1}) int x;
            mixin HiBONRecord;
        }

        { // No effect
            FixedStruct s;
            s.x = 42;
            const s_doc = s.toDoc;
            const result = FixedStruct(s_doc);
            assert(result.x is 42);
            check_serialize(s, s_doc);
        }

        { // Because x=17 is filtered out the fixed -1 value will be set
            FixedStruct s;
            s.x = 17;
            const s_doc = s.toDoc;
            const result = FixedStruct(s_doc);
            assert(result.x is -1);
            check_serialize(s, s_doc);
        }
    }

    {
        static struct ImplicitTypes {
            ushort u_s;
            short i_s;
            ubyte u_b;
            byte i_b;
            mixin HiBONRecord;
        }

        { //
            ImplicitTypes s;
            s.u_s = 42_000;
            s.i_s = -22_000;
            s.u_b = 142;
            s.i_b = -42;

            const s_doc = s.toDoc;
            const result = ImplicitTypes(s_doc);
            assert(result.u_s == 42_000);
            assert(result.i_s == -22_000);
            assert(result.u_b == 142);
            assert(result.i_b == -42);
            check_serialize(s, s_doc);
        }

    }

    /// Associative Array with integral key
    {
        static struct ArrayKey(Key) {
            string[Key] a;
            mixin HiBONRecord;
        }

        import std.algorithm.sorting : sort;
        import std.array : array, byPair;

        { /// This is stored as an HiBON array because the key-type is an uint

            ArrayKey!uint a_uint;
            string[uint] days = [1: "Monday", 2: "Tuesday", 3: "Wednesday"];
            a_uint.a = days;

            const a_toDoc = a_uint.toDoc;
            auto result = ArrayKey!uint(a_toDoc);

            enum key_sort = q{a.key < b.key};

            assert(equal(
                    result.a.byPair.array.sort!key_sort,
                    a_uint.a.byPair.array.sort!key_sort)
            );
            check_serialize(a_uint, a_toDoc);
        }

        { // This store as a list of Document arrays [[ int, string]...] because 
            // Because int is an valid HiBON key
            ArrayKey!int a_int;
            string[int] days = [1: "Monday", 2: "Tuesday", 3: "Wednesday"];
            a_int.a = days;

            const a_toDoc = a_int.toDoc;
            auto result = ArrayKey!int(a_toDoc);

            enum key_sort = q{a.key < b.key};

            assert(equal(
                    result.a.byPair.array.sort!key_sort,
                    a_int.a.byPair.array.sort!key_sort)
            );
            check_serialize(a_int, a_toDoc);
        }
    }
}

unittest {
    import tagion.utils.StdTime;

    { /// Single time element
        static struct Time {
            @label("$t") sdt_t time;
            mixin HiBONRecord;
        }

        Time expected_time;
        expected_time.time = 12_345_678;
        const doc = expected_time.toDoc;
        const result = Time(doc);
        auto h = expected_time.toHiBON;

        assert(expected_time == result);
    }

    {
        static struct Times {
            sdt_t[] times;
            mixin HiBONRecord;
        }

        Times expected_times;
        expected_times.times = [sdt_t(12_345), sdt_t(23_456), sdt_t(1345)];
        const doc = expected_times.toDoc;
        const result = Times(doc);
        assert(expected_times == result);
    }
}

///
unittest { /// Reserved keys and types
{ /// Check for reserved HiBON types
        @recordType("$@")
        static struct S {
            int x;
            mixin HiBONRecord;
        }

        S s;
        const doc = s.toDoc;
        assert(doc.valid is Document.Element.ErrorCode.RESERVED_HIBON_TYPE);
    }
    { /// Check for reserved keys 
        static struct S {
            @label("$@x") int x;
            mixin HiBONRecord;
        }

        S s;
        const doc = s.toDoc;
        assert(doc.valid is Document.Element.ErrorCode.RESERVED_KEY);
    }
}

///
unittest { // Test UDA preserve
    static struct S {
        @preserve int[] array;
        mixin HiBONRecord;
    }

    S s;
    s.array.length = 7;
    const s_serialize = s.serialize;
    const hibon_serialize = s.toHiBON.serialize;
    assert(s_serialize == hibon_serialize);

}

/// #key should should be place before recordType $@
unittest {
    @recordType("TypeS")
    static struct S {
        @label("#key") string key;
        mixin HiBONRecord;
    }

    S s;
    s.key = "some text";
    const s_serialize = s.serialize;

    const hibon_serialize = s.toHiBON.serialize;
    assert(s_serialize == hibon_serialize);

}

unittest {
    import std.typecons;
    import std.format;
    import std.range;

    @recordType("RefS")
    static struct RefS {
        string text;
        int zoom;
        mixin HiBONRecord;
    }

    static struct IS {
        immutable(RefS)* refs;
        mixin HiBONRecord;
    }

    { // Single pointer element
        IS s;
        s.refs = new RefS("text", 10);
        const s_doc = s.toDoc;
        const s_expected = IS(s_doc);
        assert(s.serialize == s_expected.serialize);
        auto h = s.toHiBON;
        assert(s.serialize == h.serialize);
        assert(s.toJSON == s_expected.toJSON);
    }
    static struct AS {
        immutable(RefS)*[] refs;
        mixin HiBONRecord;
    }

    { // Array of pointers
        AS s;
        const i = 3;
        s.refs = 3.iota.map!(i => new immutable(RefS)(format("text_%d", i), i)).array;
        const s_doc = s.toDoc;
        const s_expected = AS(s_doc);
        assert(s.serialize == s_expected.serialize);
        auto h = s.toHiBON;
        assert(s.serialize == h.serialize);
        assert(s.toJSON == s_expected.toJSON);

    }

    { // Sparsed array of pointers
        AS s;
        const i = 3;
        static immutable(RefS)* create(const int i) {
            if ((i % 2) == 0) {
                return new immutable(RefS)(format("text_%d", i), i);
            }
            return null;
        }

        s.refs = 3.iota.map!create.array;
        const s_doc = s.toDoc;
        const s_expected = AS(s_doc);
        assert(s.serialize == s_expected.serialize);
        auto h = s.toHiBON;
        assert(s.serialize == h.serialize);
        assert(s.toJSON == s_expected.toJSON);

    }
}
