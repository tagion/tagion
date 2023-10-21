module tagion.hibon.HiBONRecord;

import std.stdio;
import tagion.hibon.HiBONJSON;

import std.exception : assumeUnique, assumeWontThrow;
import std.typecons : Tuple, Yes, No;
import std.traits;

import tagion.basic.basic : basename, EnumContinuousSequency;
import tagion.hibon.HiBONBase : ValueT;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONException : HiBONRecordException;

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
	Param: T is the type of the recorder to be checked
Param: doc 
	Returns: true if the doc has the correct Recorder type 
*/
@safe
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
 * Gets the doc[TYPENAME] from the document.
 * Params:
 *   doc = Document containing typename
 * Returns: TYPENAME or string.init
 */
@safe
string getType(const Document doc) pure {
    if (doc.hasMember(TYPENAME)) {
        return doc[TYPENAME].get!string;
    }
    return string.init;
}

enum STUB = HiBONPrefix.HASH ~ "";
@safe bool isStub(const Document doc) pure {
    return !doc.empty && doc.keys.front == STUB;
}

enum HiBONPrefix {
    HASH = '#',
    PARAM = '$',
}

@safe
bool hasHashKey(T)(T doc) if (is(T : const(HiBON)) || is(T : const(Document))) {
    return !doc.empty && doc.keys.front[0] is HiBONPrefix.HASH && doc.keys.front != STUB;
}

@safe
unittest {
    import std.range : iota;
    import std.array : array;

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
    import std.traits : isAssociativeArray, isUnsigned, KeyType;

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

struct optional; /// This flag is set to true if this paramer is optional
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
    string code;
}

/++
 Sets the HiBONRecord type
 +/
struct recordType {
    string name;
    string code; // This is is mixed after the Document constructor
}
/++
 Gets the label for HiBON member
 Params:
 member = is the member alias
 +/
template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;

    static if (hasUDA!(member, label)) {
        enum _label = getUDAs!(member, label)[0];
        static if (_label.name == VOID) {
            enum GetLabel = label(basename!(member));
        }
        else {
            enum GetLabel = _label;
        }
    }
    else {
        enum GetLabel = label(basename!(member));
    }
}

enum TYPENAME = HiBONPrefix.PARAM ~ "@";
enum VOID = "*";

mixin template HiBONRecordType() {
    import tagion.hibon.Document : Document;
    import tagion.hibon.HiBONRecord : TYPENAME, recordType;
    import std.traits : getUDAs, hasUDA, isIntegral, isUnsigned;

    alias ThisType = typeof(this);

    static if (hasUDA!(ThisType, recordType)) {
        alias record_types = getUDAs!(ThisType, recordType);
        static assert(record_types.length is 1, "Only one recordType UDA allowed");
        static if (record_types[0].name.length) {
            enum type_name = record_types[0].name;
            import tagion.hibon.HiBONRecord : isRecordT = isRecord;

            alias isRecord = isRecordT!ThisType;
            version (none) static bool isRecord(const Document doc) nothrow {
                if (doc.hasMember(TYPENAME)) {
                    return doc[TYPENAME].get!string == type_name;
                }
                return false;
            }
        }
    }
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
 @label("") bool dummy;   // This parameter is not included in the HiBON
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

    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType,
        Unqual, hasMember, isCallable,
        EnumMembers, ForeachType, isArray, isAssociativeArray, KeyType, ValueType;
    import std.typecons : Tuple;
    import std.format;
    import std.functional : unaryFun;
    import std.range : iota, enumerate, lockstep;
    import std.range.primitives : isInputRange;
    import std.algorithm.iteration : map;
    import std.meta : staticMap, AliasSeq;
    import std.array : join, array, assocArray;

    import tagion.basic.basic : basename, EnumContinuousSequency;

    //    import tagion.hibon.HiBONException : check;
    import tagion.basic.Message : message;
    import tagion.basic.basic : basename, CastTo;
    import tagion.basic.tagionexceptions : Check;
    import tagion.hibon.HiBONException : HiBONRecordException;
    import tagion.hibon.HiBONRecord : isHiBON, isHiBONRecord, HiBONRecordType,
        label, optional, GetLabel, filter, fixed, inspect, VOID;
    import HiBONRecord = tagion.hibon.HiBONRecord;

    import tagion.hibon.HiBONBase : TypedefBase;

    protected alias check = Check!(HiBONRecordException);

    import tagion.hibon.HiBONJSON : JSONString;
    import tagion.hibon.HiBON : HiBON;

    mixin JSONString;

    mixin HiBONRecordType;
    alias isRecord = HiBONRecord.isRecord!ThisType;

    enum HAS_TYPE = hasMember!(ThisType, "type_name");
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

    @trusted final inout(HiBON) toHiBON() inout {
        auto hibon = new HiBON;
        static HiBON toList(L)(L list) {
            import std.array : byPair, array;
            import std.algorithm : sort;
            import std.range : refRange;
            import std.algorithm.iteration : map;
            import std.typecons : tuple;

            auto result = new HiBON;
            alias UnqualL = Unqual!L;
            alias ElementT = Unqual!(TypedefBase!(ForeachType!L));
            static if (isArray!L || isAssociativeArray!L) {
                static if (isSpecialKeyType!L) {
                    uint list_index;
                    alias Pair = ForeachType!(typeof(list.byPair));
                    static struct SwapAble {
                        Pair elm;
                    }

                    auto range = list.byPair
                        .map!(pair => new SwapAble(pair))
                        .array
                        .sort!((a, b) => less_than(a.elm.key, b.elm.key))
                        .map!(a => tuple(a.elm.key, a.elm.value));
                }
                else {
                    auto range = list;
                }
            }
            else {
                auto range = list.enumerate;
            }
            foreach (index, e; range) {
                void set(Index, Value)(Index key, Value value) {
                    static if (isSpecialKeyType!L) {
                        auto element = new HiBON;
                        alias BaseIndex = TypedefBase!Index;
                        static if (HiBON.Value.hasType!BaseIndex || is(BaseIndex == enum)) {
                            element[0] = Index(key);
                        }
                        else static if (isHiBONRecord!BaseIndex) {
                            element[0] = BaseIndex(key.toDoc);
                        }
                        else {
                            assert(0, format("Index %s is not supported", Index.stringof));
                        }
                        element[1] = value;
                        result[list_index++] = element;
                    }
                    else {
                        result[index] = value;
                    }
                }

                static if (HiBON.Value.hasType!ElementT || is(ElementT == enum)) {
                    set(index, e);
                }
                else static if (isHiBON!ElementT) {
                    set(index, e.toHiBON);
                }
                else static if (isInputRange!ElementT) {
                    set(index, toList(e));
                }
                else {
                    static assert(0, format("Can not convert %s to HiBON", L.stringof));
                }
            }
            return result;
        }

        MemberLoop: foreach (i, m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                enum default_name = basename!(this.tupleof[i]);
                alias label = GetLabel!(this.tupleof[i]);
                enum name = label.name;
                // }
                // else {
                //     enum name=basename!(this.tupleof[i]);
                // }
                static if (hasUDA!(this.tupleof[i], filter)) {
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
                static if (name.length) {
                    alias MemberT = typeof(m);
                    alias BaseT = TypedefBase!MemberT;
                    alias UnqualT = Unqual!BaseT;
                    // writefln("name=%s BaseT=%s isInputRange!BaseT=%s isInputRange!UnqualT=%s",
                    //     name, BaseT.stringof, isInputRange!BaseT, isInputRange!UnqualT);
                    static if (HiBON.Value.hasType!UnqualT) {
                        hibon[name] = cast(BaseT) m;
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
                                    format(`A sub class/struct '%s' of type %s must have a toHiBON or must be ingnored with @label("") UDA tag`,
                                    name, BaseT.stringof));
                            hibon[name] = cast(BaseT) m;
                        }
                    }
                    else static if (isInputRange!UnqualT || isAssociativeArray!UnqualT) {
                        alias BaseU = TypedefBase!(ForeachType!(UnqualT));
                        hibon[name] = toList(m);
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
                        static assert(0, format("Convering for member '%s' of type %s is not supported by default",
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

    //    import std.traits : FieldNameTuple, Fields;

    template GetKeyName(uint i) {
        enum default_name = basename!(this.tupleof[i]);
        static if (hasUDA!(this.tupleof[i], label)) {
            alias label = GetLabel!(this.tupleof[i]);
            enum GetKeyName = (label.name == VOID) ? default_name : label.name;
        }
        else {
            enum GetKeyName = default_name;
        }
    }

    /++
     Returns:
     The a list of Record keys
     +/
    protected static string[] _keys() pure nothrow {
        string[] result;
        alias ThisTuple = typeof(ThisType.tupleof);
        static foreach (i; 0 .. ThisTuple.length) {
            result ~= GetKeyName!i;
        }
        return result;
    }

    enum keys = _keys;

    // version(none) {
    //     alias KeyType = Tuple!(string, "key", string, "type");

    //     static auto getKeyType() {
    //         alias ThisTuple = typeof(ThisType.tupleof);

    //     }

    //     static bool isValid() pure nothrow {

    //         return 
    //     }
    // }

    static if (!NO_DEFAULT_CTOR) {
        @safe this(const HiBON hibon) {
            this(Document(hibon.serialize));
        }

        @safe this(const Document doc) {
            static if (HAS_TYPE) {
                string _type = doc[TYPENAME].get!string;
                check(_type == type_name, format("Wrong %s type %s should be %s",
                        TYPENAME, _type, type_name));
            }
            static if (hasUDA!(ThisType, recordType)) {
                enum record = getUDAs!(ThisType, recordType)[0];
                static if (record.code) {
                    scope (exit) {
                        mixin(record.code);
                    }
                }
            }
            static R toList(R)(const Document doc) {
                alias MemberU = ForeachType!(R);
                alias BaseU = TypedefBase!MemberU;
                static if (isArray!R) {
                    alias UnqualU = Unqual!MemberU;
                    check(doc.isArray, format("Document is expected to be an array"));
                    MemberU[] result;
                    result.length = doc.length;
                    result = doc[].map!(e => e.get!MemberU).array;
                    enum do_foreach = false;
                }
                else static if (isSpecialKeyType!R) {
                    R result;
                    enum do_foreach = true;
                }
                else static if (isAssociativeArray!R) {
                    alias ValueT = ForeachType!R;
                    alias KeyT = KeyType!R;
                    R result = assocArray(
                            doc.keys.map!(key => key.to!KeyT),
                            doc[].map!(e => e.get!ValueT));
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

            enum do_valid = hasMember!(ThisType, "valid")
                && isCallable!(valid) && __traits(compiles, valid(doc));
            static if (do_valid) {
                check(valid(doc),
                        format("Document verification faild for HiBONRecord %s",
                        ThisType.stringof));
            }

            enum do_verify = hasMember!(ThisType, "verify")
                && isCallable!(verify) && __traits(compiles, this.verify());

            static if (do_verify) {
                scope (exit) {
                    check(this.verify(),
                            format("Document verification faild for HiBONRecord %s",
                            ThisType.stringof));
                }
            }

            alias ThisTuple = typeof(ThisType.tupleof);
            ForeachTuple: foreach (i, ref m; this.tupleof) {
                static if (__traits(compiles, typeof(m))) {
                    enum default_name = basename!(this.tupleof[i]);
                    enum optional_flag = hasUDA!(this.tupleof[i], optional);
                    static if (hasUDA!(this.tupleof[i], label)) {
                        alias label = GetLabel!(this.tupleof[i]);
                        enum name = (label.name == VOID) ? default_name : label.name;
                        //enum optional_flag = label.optional || hasUDA!(this.tupleof[i], optional);
                        static if (optional_flag) {
                            if (!doc.hasMember(name)) {
                                continue ForeachTuple;
                            }
                        }
                        static if (HAS_TYPE) {
                            static assert(TYPENAME != label.name,
                                    format("Fixed %s is already definded to %s but is redefined for %s.%s",
                                    TYPENAME, TYPE, ThisType.stringof,
                                    basename!(this.tupleof[i])));
                        }
                    }
                else {
                        enum name = default_name;
                    }
                    static if (name.length) {
                        static if (hasUDA!(this.tupleof[i], fixed)) {
                            alias assigns = getUDAs!(this.tupleof[i], fixed);
                            static assert(assigns.length is 1,
                                    "Only one fixed UDA allowed per member");
                            static assert(!optional_flag, "The optional parameter in label can not be used in connection with the fixed attribute");
                            enum code = format(q{this.tupleof[i]=%s;}, assigns[0].code);
                            if (!doc.hasMember(name)) {
                                mixin(code);
                                continue ForeachTuple;
                            }
                        }
                        enum member_name = this.tupleof[i].stringof;
                        alias MemberT = typeof(m);
                        //alias BaseT = TypedefBase!MemberT;
                        alias BaseT = MemberT;
                        alias UnqualT = Unqual!BaseT;
                        static if (optional_flag) {
                            if (!doc.hasMember(name)) {
                                continue ForeachTuple;
                            }
                        }
                        static if (hasUDA!(this.tupleof[i], inspect)) {
                            alias Inspects = getUDAs!(this.tupleof[i], inspect);
                            scope (exit) {
                                static foreach (F; Inspects) {
                                    {
                                        alias inspectFun = unaryFun!(F.code);
                                        check(inspectFun(m),
                                                message("Member %s failed on inspection %s with %s",
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
                                    format("Convering for member '%s' of type %s is not supported by default",
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

    @safe final const(Document) toDoc() const {
        return Document(toHiBON.serialize);
    }
}

@safe unittest {
    import std.stdio;
    import std.format;
    import std.exception : assertThrown, assertNotThrown;
    import std.traits : OriginalType, staticMap, Unqual;
    import std.meta : AliasSeq;
    import std.range : lockstep;
    import std.algorithm.comparison : equal;
    import tagion.hibon.HiBONException : HiBONException, HiBONRecordException;

    @recordType("SIMPEL") static struct Simpel {
        int s;
        string text;
        mixin HiBONRecord!(q{
                this(int s, string text) {
                    this.s=s; this.text=text;
                }
            });

    }

    @recordType("SIMPELLABEL") static struct SimpelLabel {
        @label("$S") int s;
        @label("TEXT") string text;
        mixin HiBONRecord!(q{
                this(int s, string text) {
                    this.s=s; this.text=text;
                }
            });
    }

    @recordType("BASIC") static struct BasicData {
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

    template SimpelOption(string LABEL = "") {
        @recordType(LABEL)
        static struct SimpelOption {
            int not_an_option;
            @label("s") @optional int s;
            @optional string text;
            mixin HiBONRecord!();
        }
    }

    { // Simpel basic type check
    {
            const s = Simpel(-42, "some text");
            const docS = s.toDoc;
            // writefln("keys=%s", docS.keys);
            assert(docS["s"].get!int == -42);
            assert(docS["text"].get!string == "some text");
            assert(docS[TYPENAME].get!string == Simpel.type_name);
            assert(isRecord!Simpel(docS));
            const s_check = Simpel(docS);
            // const s_check=Simpel(s);
            assert(s == s_check);
            assert(s_check.toJSON.toString == format("%j", s_check));

            assert(isRecord!Simpel(docS));
            assert(!isRecord!SimpelLabel(docS));
        }

        {
            const s = SimpelLabel(42, "other text");
            const docS = s.toDoc;
            assert(docS["$S"].get!int == 42);
            assert(docS["TEXT"].get!string == "other text");
            assert(docS[TYPENAME].get!string == SimpelLabel.type_name);
            assert(isRecord!SimpelLabel(docS));
            const s_check = SimpelLabel(docS);

            assert(s == s_check);

            immutable s_imut = SimpelLabel(docS);
            assert(s_imut == s_check);
        }

        {
            const s = BasicData(-42, 42, -42_000_000_000UL, 42_000_000_000L,
                    42.42e-9, -42.42e-300, "text", true);
            const docS = s.toDoc;

            const s_check = BasicData(docS);

            assert(s == s_check);
            immutable s_imut = BasicData(docS);
            assert(s_imut == s_check);
        }
    }

    { // Check option
        alias NoLabel = SimpelOption!("");
        alias WithLabel = SimpelOption!("LBL");

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
            const doc = s.toDoc;
            // writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
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
            @recordType("NotBoth") static struct NotBoth {
                static if (FILTER) {
                    @optional @(filter.Initialized) int x;
                    @optional @(filter.Initialized) @filter(q{a < 42}) int y;
                }
                else {
                    @optional int x;
                    @optional int y;
                }
                bool valid(const Document doc) {
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

        // writefln("docS=\n%s", s_filter_x.toDoc.toJSON(true).toPrettyString);
        // writefln("docS=\n%s", s_filter_y.toDoc.toJSON(true).toPrettyString);
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
            //            const x=NotBothFilter(s_dont_filter_xy_doc);
            //            const x=NotBothNoFilter(s_dont_filter_xy_doc)
        }

        {
            const s_filter_42 = NotBothFilter(12, 42);
            const s_filter_42_doc = s_filter_42.toDoc;
            const s_filter_not_42 = NotBothFilter(s_filter_42.toDoc);
            assert(s_filter_not_42 == NotBothFilter(12, int.init));
        }
        // const s_no_filter_x=NotBothNoFilter(11, int.init);
        // const s_no_filter_y=NotBothNoFilter(int.init, 13);
        // const s_dont_no_filter=NotBothNoFilter();
        // const s_dont_no_filter_xy=NotBothNoFilter(11, 13);

        // writefln("docS=\n%s", s_no_filter_x.toDoc.toJSON(true).toPrettyString);
        // writefln("docS=\n%s", s_no_filter_y.toDoc.toJSON(true).toPrettyString);
        // writefln("docS=\n%s", s_dont_no_filter.toDoc.toJSON(true).toPrettyString);
        // writefln("docS=\n%s", s_dont_no_filter_xy.toDoc.toJSON(true).toPrettyString);

    }

    {
        @safe static struct SuperStruct {
            Simpel sub;
            string some_text;
            mixin HiBONRecord!(q{
                    this(string some_text, int s, string text) {
                        this.some_text=some_text;
                        sub=Simpel(s, text);
                    }
                });
        }

        const s = SuperStruct("some_text", 42, "text");
        const doc = s.toDoc;
        const s_converted = SuperStruct(doc);
        assert(s == s_converted);
        assert(doc.toJSON.toString == format("%j", s_converted));
        assert(doc.toJSON.toPrettyString == format("%J", s_converted));
    }

    {
        @safe static class SuperClass {
            Simpel sub;
            string class_some_text;
            mixin HiBONRecord!(q{
                    this(string some_text, int s, string text) @safe {
                        this.class_some_text=some_text;
                        sub=Simpel(s, text);
                    }
                });
        }

        const s = new SuperClass("some_text", 42, "text");
        const doc = s.toDoc;
        const s_converted = new SuperClass(doc);
        assert(doc == s_converted.toDoc);

        // For some reason SuperClass because is a class format is not @safe
        (() @trusted {
            assert(doc.toJSON.toString == format("%j", s_converted));
            assert(doc.toJSON.toPrettyString == format("%J", s_converted));
        })();
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
            int[] a;
            mixin HiBONRecord;
        }

        Array s;
        s.a = [17, 42, 17];

        const doc = s.toDoc;
        const result = Array(doc);
        assert(s == result);
        assert(doc.toJSON.toString == format("%j", result));

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
    }

    { // Element as range
        @safe static struct Range(T) {
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

            @trusted this(const Document doc) {
                auto result = new UnqualT[doc.length];
                foreach (ref a, e; lockstep(result, doc[])) {
                    a = e.get!T;
                }
                array = result;
            }
        }

        @safe auto StructWithRangeTest(T)(T[] array) {
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
            const s = StructWithRangeTest(array);

            const doc = s.toDoc;
            alias ResultT = typeof(s);

            const s_doc = ResultT(doc);

            assert(s_doc == s);
            assert(doc.toJSON.toString == format("%j", s));
        }

        { // Range of structs
            Simpel[] simpels;
            simpels ~= Simpel(1, "one");
            simpels ~= Simpel(2, "two");
            simpels ~= Simpel(3, "three");
            {
                auto s = StructWithRangeTest(simpels);
                alias StructWithRange = typeof(s);
                {
                    auto h = new HiBON;
                    h["s"] = s;

                    const s_get = h["s"].get!StructWithRange;
                    assert(s == s_get);
                }
            }

            {
                static struct SimpelArray {
                    Simpel[] array;
                    mixin HiBONRecord;
                }

                { // SimpelArray with empty array
                    SimpelArray s;
                    auto h = new HiBON;
                    h["s"] = s;
                    const s_get = h["s"].get!SimpelArray;
                    assert(s_get == s);
                }
                {
                    SimpelArray s;
                    s.array = simpels;
                    auto h = new HiBON;
                    h["s"] = s;

                    const s_get = h["s"].get!SimpelArray;

                    assert(s_get == s);
                    const s_doc = s_get.toDoc;

                    const s_array = s_doc["array"].get!(Simpel[]);
                    assert(equal(s_array, s.array));

                    const s_result = SimpelArray(s_doc);
                    assert(s_result == s);
                }
            }
        }

        { // Jagged Array
            @safe static struct Jagged {
                Simpel[][] y;
                mixin HiBONRecord;
            }

            Simpel[][] ragged = [
                [Simpel(1, "one"), Simpel(2, "one")],
                [Simpel(1, "two"), Simpel(2, "two"), Simpel(3, "two")],
                [Simpel(1, "three")]
            ];

            Jagged jagged;
            jagged.y = ragged;

            const jagged_doc = jagged.toDoc;

            const result = Jagged(jagged_doc);

            assert(jagged == result);

            assert(jagged_doc.toJSON.toString == format("%j", jagged));

        }

        {
            @safe static struct Associative {
                Simpel[string] a;
                mixin HiBONRecord;
            }

            Associative associative;
            associative.a["$one"] = Simpel(1, "one");
            associative.a["$two"] = Simpel(1, "two");
            associative.a["$three"] = Simpel(1, "three");

            // writefln("%J", associative);

            const associative_doc = associative.toDoc;

            const result = Associative(associative_doc);
            (() @trusted {
                assert(equal(result.a.keys, associative.a.keys));
                assert(equal(result.a.byValue, associative.a.byValue));
            })();

            assert(associative_doc.toJSON.toString == format("%j", associative));

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
        }

    }

    { // None standard Keys
        import std.typecons : Typedef;
        import std.algorithm : map, each;
        import std.range : tee;
        import std.algorithm : sort;
        import std.array : array;
        import std.typecons : tuple;
        import std.algorithm.sorting : isStrictlyMonotonic;
        import std.stdio;

        import tagion.basic.Types : Buffer;

        static void binwrite(Args...)(ubyte[] buf, Args args) @trusted {
            import std.bitmanip : write;

            write(buf, args);
        }
        //        alias binwrite=assumeTrusted!(bitmanip.write!Buffer);
        { // Typedef on HiBON.type is used as key in an associative-array
            pragma(msg, "fixme(cbr): make sure that the assoicated array is hash invariant");
            alias Bytes = Typedef!(immutable(ubyte)[], null, "Bytes");
            alias Tabel = int[Bytes];
            static struct StructBytes {
                Tabel tabel;
                mixin HiBONRecord;
            }

            static assert(isSpecialKeyType!Tabel);

            import std.outbuffer;

            Tabel tabel;
            auto list = [-17, 117, 3, 17, 42];
            auto buffer = new ubyte[int.sizeof];
            foreach (i; list) {
                binwrite(buffer, i, 0);
                tabel[Bytes(buffer.idup)] = i;
            }

            StructBytes s;
            s.tabel = tabel;
            const s_doc = s.toDoc;
            const result = StructBytes(s_doc);

            assert(
                    equal(
                    list
                    .map!((i) { binwrite(buffer, i, 0); return tuple(buffer.idup, i); })
                    .array
                    .sort,
                    s_doc["tabel"]
                    .get!Document[]
                    .map!(e => tuple(e.get!Document[0].get!Buffer, e.get!Document[1].get!int))
            ));
            assert(s_doc == result.toDoc);
        }

        { // Typedef of a HiBONRecord is used as key in an associative-array
            static struct KeyStruct {
                int x;
                string text;
                mixin HiBONRecord!(q{
                        this(int x, string text) {
                            this.x=x; this.text=text;
                        }
                    });
            }

            alias Key = Typedef!(KeyStruct, KeyStruct.init, "Key");

            alias Tabel = int[Key];

            static struct StructKeys {
                Tabel tabel;
                mixin HiBONRecord;
            }

            Tabel list = [
                Key(KeyStruct(2, "two")): 2, Key(KeyStruct(4, "four")): 4,
                Key(KeyStruct(1, "one")): 1, Key(KeyStruct(3, "three")): 3
            ];

            StructKeys s;
            s.tabel = list;

            const s_doc = s.toDoc;

            // Checks that the key is ordered in the tabel
            assert(s_doc["tabel"].get!Document[].map!(
                    a => a.get!Document[0].get!Document.serialize).array.isStrictlyMonotonic);

            const result = StructKeys(s_doc);
            //assert(result == s);
            assert(result.toDoc == s.toDoc);

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
        }

        { // Because x=17 is filtered out the fixed -1 value will be set
            FixedStruct s;
            s.x = 17;
            const s_doc = s.toDoc;
            const result = FixedStruct(s_doc);
            assert(result.x is -1);
        }
    }

    {
        static struct ImpliciteTypes {
            ushort u_s;
            short i_s;
            ubyte u_b;
            byte i_b;
            mixin HiBONRecord;
        }

        { //
            ImpliciteTypes s;
            s.u_s = 42_000;
            s.i_s = -22_000;
            s.u_b = 142;
            s.i_b = -42;

            const s_doc = s.toDoc;
            const result = ImpliciteTypes(s_doc);
            assert(result.u_s == 42_000);
            assert(result.i_s == -22_000);
            assert(result.u_b == 142);
            assert(result.i_b == -42);
        }

    }

    /// Associative Array with integral key
    {
        static struct ArrayKey(Key) {
            string[Key] a;
            mixin HiBONRecord;
        }

        {
            import std.algorithm.sorting : sort;
            import std.array : array, byPair;

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
        }
    }
}

@safe
unittest {
    import tagion.utils.StdTime;

    { /// Single time element
        static struct Time {
            @label("$t") sdt_t time;
            mixin HiBONRecord;
        }

        Time expected_time;
        expected_time.time = 12345678;
        const doc = expected_time.toDoc;
        const result = Time(doc);
        assert(expected_time == result);
    }

    {
        static struct Times {
            sdt_t[] times;
            mixin HiBONRecord;
        }

        Times expected_times;
        expected_times.times = [sdt_t(12345), sdt_t(23456), sdt_t(1345)];
        const doc = expected_times.toDoc;
        const result = Times(doc);
        assert(expected_times == result);
    }
}

///
@safe
unittest { /// Reseved keys and types

{ /// Check for reseved HiBON types
        @recordType("$@")
        static struct S {
            int x;
            mixin HiBONRecord;
        }

        S s;
        const doc = s.toDoc;
        assert(doc.valid is Document.Element.ErrorCode.RESERVED_HIBON_TYPE);
    }
    { /// Check for reseved keys 
        static struct S {
            @label("$@x") int x;
            mixin HiBONRecord;
        }

        S s;
        const doc = s.toDoc;
        assert(doc.valid is Document.Element.ErrorCode.RESERVED_KEY);
    }

}
