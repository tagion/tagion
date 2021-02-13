module tagion.hibon.HiBONRecord;

//import std.stdio;
import tagion.hibon.HiBONJSON;

import file=std.file;
import std.exception : assumeUnique;
import std.typecons : Tuple;
import std.traits : hasMember, ReturnType, isArray, ForeachType;

import tagion.basic.Basic : basename, EnumContinuousSequency;
import tagion.hibon.HiBONBase : ValueT;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONException : HiBONRecordException;

alias DocResult=Tuple!(Document.Element.ErrorCode, "error", string , "key");

///  Returns: true if struct or class supports toHiBON
enum isHiBON(T)=(is(T == struct) || is(T == class)) && hasMember!(T, "toHiBON") && (is(ReturnType!(T.toHiBON) : const(HiBON)));

///  Returns: true if struct or class supports toDoc
enum isHiBONRecord(T)=(is(T == struct) || is(T == class)) && hasMember!(T, "toDoc") && (is(ReturnType!(T.toDoc) : const(Document)));

enum isHiBONRecordArray(T)=isArray!T && isHiBONRecord!(ForeachType!T);

enum STUB=HiBONPrefix.HASH~"";
@safe
bool isStub(const Document doc) {
    auto range=doc[];
    return !range.empty && range.front.key == STUB;
}

/++
 Label use to set the HiBON member name
 +/
struct Label {
    string name;   /// Name of the HiBON member
    bool optional; /// This flag is set to true if this paramer is optional
}

/++
 Filter attribute for toHiBON
 +/
struct Filter {
    string code; /// Filter function
    enum Initialized=Filter(q{a !is a.init});
}

/++
 Validates the Document type on construction
 +/
struct Inspect {
    string code; ///
    enum Initialized=Filter(q{a !is a.init});
}

/++
 Used to set a member value from the information in t
 +/
struct Assign {
    string code;
}
/++
 Sets the HiBONRecord type
 +/
struct RecordType {
    string name;
    string code; // This is is mixed after the Document constructor
}
/++
 Gets the Label for HiBON member
 Params:
 member = is the member alias
 +/
template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;
    static if (hasUDA!(member, Label)) {
        enum GetLabel=getUDAs!(member, Label)[0];
    }
    else {
        enum GetLabel=Label(basename!(member));
    }
}

enum HiBONPrefix {
    HASH = '#',
    PARAM = '$'
}

bool hasHashKey(T)(T doc) if (is(T:const(HiBON)) || is(T:const(Document))) {
    return !doc.empty && doc.keys.front[0] is HiBONPrefix.HASH;
}

// bool hasHashKey(T)(T value) if (isHiBONRecord!T) {
//     return value.keys[0] is HiBONPrefix.HASH;
// }

enum TYPENAME=HiBONPrefix.PARAM~"@";
enum VOID="*";

enum Choice {
    NONE,
    CONFINED
}
/++
 HiBON Helper template to implement constructor and toHiBON member functions
 Params:
 TYPE = is used to set a HiBON record type (TYPENAME)
 Examples:
 --------------------
 struct Test {
 @Label("$X") uint x; // The member in HiBON is "$X"
 string name;         // The member in HiBON is "name"
 @Label("num", true); // The member in HiBON is "num" and is optional
 @Label("") bool dummy; // This parameter is not included in the HiBON
 HiBONRecord!("TEST");   // The "$type" is set to "TEST"
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
mixin template HiBONRecord(string CTOR="") {

    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual, hasMember,
        isCallable, EnumMembers, ForeachType, isArray, isAssociativeArray, KeyType, ValueType;
    import std.typecons : TypedefType, Tuple;
    import std.format;
    import std.functional : unaryFun;
    import std.range : iota, enumerate, lockstep;
    import std.range.primitives : isInputRange;
    import std.meta : staticMap, AliasSeq;
    import std.array : join;

    import tagion.basic.Basic : basename, EnumContinuousSequency;

//    import tagion.hibon.HiBONException : check;
    import tagion.basic.Message : message;
    import tagion.basic.Basic : basename, CastTo;
    import tagion.basic.TagionExceptions : Check;
    import tagion.hibon.HiBONException : HiBONRecordException;
    import tagion.hibon.HiBONRecord : isHiBON;
    protected alias check=Check!(HiBONRecordException);

    import tagion.hibon.HiBONJSON : JSONString;
    mixin JSONString;

    alias ThisType=typeof(this);

    static if (hasUDA!(ThisType, RecordType)) {
        alias record_types=getUDAs!(ThisType, RecordType);
        static assert(record_types.length is 1, "Only one RecordType UDA allowed");
        static if (record_types[0].name.length) {
            enum type=record_types[0].name;
        }
    }

    enum HAS_TYPE=hasMember!(ThisType, "type");

    @trusted final inout(HiBON) toHiBON() inout {
        auto hibon= new HiBON;
        static HiBON toList(L)(L list) {
            auto array=new HiBON;
            alias UnqualL=Unqual!L;
            alias ElementT=Unqual!(ForeachType!L);
            static if (isArray!L || isAssociativeArray!L) {
                auto range=list;
            }
            else {
                auto range=list.enumerate;
            }
            foreach(index, e; range) {
                static if (isHiBON!ElementT) {
                    array[index]=e.toHiBON;
                }
                else static if (HiBON.Value.hasType!ElementT) {
                    array[index]=e;
                }
                else static if (isInputRange!ElementT) {
                    array[index]=toList(e);
                }
                else {
                    static assert(0, format("Can not convert %s to HiBON", L.stringof));
                }
            }
            return array;
        }
    MemberLoop:
        foreach(i, m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                enum default_name=basename!(this.tupleof[i]);
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i]);
                    enum name=(label.name == VOID)?default_name:label.name;
                }
                else {
                    enum name=basename!(this.tupleof[i]);
                }
                static if (hasUDA!(this.tupleof[i], Filter)) {
                    alias filters=getUDAs!(this.tupleof[i], Filter);
                    static foreach(F; filters) {
                        {

                            alias filterFun=unaryFun!(F.code);
                            if (!filterFun(this.tupleof[i])) {
                                continue MemberLoop;
                            }
                        }
                    }
                }
                static if (name.length) {
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    alias UnqualT=Unqual!BaseT;
                    // writefln("name=%s BaseT=%s isInputRange!BaseT=%s isInputRange!UnqualT=%s",
                    //     name, BaseT.stringof, isInputRange!BaseT, isInputRange!UnqualT);
                    static if (HiBON.Value.hasType!UnqualT) {
                        hibon[name]=cast(BaseT)m;
                    }
                    else static if (isHiBON!BaseT) {
                        hibon[name]=m.toHiBON;
                    }
                    else static if (is(MemberT == enum)) {
                        hibon[name]=cast(OriginalType!MemberT)m;
                    }
                    else static if (is(BaseT == class) || is(BaseT == struct)) {
                        static if (isInputRange!UnqualT) {
                            alias ElementT=ForeachType!UnqualT;
                            static assert((HiBON.Value.hasType!ElementT) || isHiBON!ElementT ,
                                format("The sub element '%s' of type %s is not supported", name, BaseT.stringof));

                            hibon[name]=toList(cast(UnqualT)m);
                        }
                        else {
                            static assert(is(BaseT == HiBON) || is(BaseT : const(Document)),
                                format(`A sub class/struct '%s' of type %s must have a toHiBON or must be ingnored with @Label("") UDA tag`, name, BaseT.stringof));
                            hibon[name]=cast(BaseT)m;
                        }
                    }
                    else static if (isInputRange!UnqualT || isAssociativeArray!UnqualT) {
                        alias BaseU=TypedefType!(ForeachType!(UnqualT));
                        hibon[name]=toList(m);
                    }
                    else {
                        static assert(0, format("Convering for member '%s' of type %s is not supported by default", name, MemberT.stringof));
                    }
                }
            }
        }
        static if (HAS_TYPE) {
            hibon[TYPENAME]=type;
        }
        @nogc @trusted inout(HiBON) result() inout pure nothrow {
            return cast(inout)hibon;
        }
        return result;
    }

    enum NO_DEFAULT_CTOR=(CTOR == "{}");
    /++
     Constructors must be mixed in or else the default construction is will be removed
     +/
    static if (CTOR.length && !NO_DEFAULT_CTOR) {
        mixin(CTOR);
    }


    import std.traits : FieldNameTuple, Fields;

    template GetKeyName(uint i) {
        enum default_name=basename!(this.tupleof[i]);
        static if (hasUDA!(this.tupleof[i], Label)) {
            alias label=GetLabel!(this.tupleof[i]);
            enum GetKeyName=(label.name == VOID)?default_name:label.name;
        }
        else {
            enum GetKeyName=default_name;
        }
    }

    /++
     Returns:
     The a list of Record keys
     +/
    protected static string[] _keys() pure nothrow {
        string[] result;
        alias ThisTuple=typeof(ThisType.tupleof);
        static foreach(i; 0..ThisTuple.length) {
            result~=GetKeyName!i;
        }
        return result;
    }

    /++
     Check if the Documet is fitting the object
     Returns:
     If the Document fits compleatly it returns NONE
     +/
    version(none)
    @safe static DocResult fitting(const Document doc, string[] super_keys=null) nothrow {
        foreach(e; doc[]) {
            string key_chain(string key, string sub_key=null) {

                return (super_keys~[key, sub_key]).join(".");
            }
            switch (e.key) {
                static foreach(i, key; keys) {
                    {

                        static if (key.length) {
                            alias FieldType=Fields!ThisType[i];
                        case key:

                            alias BaseT=TypedefType!FieldType;
                            static if (!Document.Value.hasType!BaseT && (is(BaseT == struct) || is(BaseT == class))) {
                                static assert(
                                    __traits(compiles, FieldType.fitting(doc, null)),
                                    format("Member %s is missing %s of %s", key, fitting(doc).stringof, FieldType.stringof));
                                try {
                                    const sub_doc=doc[key].get!Document;
                                    return FieldType.fitting(sub_doc, super_keys~key);
                                }
                                catch (Exception e) {
                                    return DocResult(Document.Element.ErrorCode.BAD_SUB_DOCUMENT, key_chain(key));
                                }
                            }
                            else {
                                static if (is(FieldType == enum)) {
                                    alias DocType=TypedefType!(OriginalType!FieldType);
                                }
                                else {
                                    alias DocType=TypedefType!(FieldType);
                                }
                                static if (Document.Value.hasType!DocType) {
                                    enum TypeE=Document.Value.asType!DocType;
                                    if (TypeE !is e.type) {
                                        return DocResult(Document.Element.ErrorCode.ILLEGAL_TYPE, key_chain(key));
                                    }
                                }
                                else static if (isInputRange!DocType) {
                                    alias ElementT=TypedefType!(ForeachType!DocType);
                                    if (!doc.isArray) {
                                        return DocResult(Document.Element.ErrorCode.NOT_AN_ARRAY, key_chain(key));
                                    }
                                    foreach(sub_e; doc[]) {
                                        try {
                                            static if (isHiBONRecord!ElementT) {
                                                const sub_doc=sub_e.get!Document;
                                                const result=ElementT.fitting(sub_doc);
                                                if (result.error !is Document.Element.ErrorCode.NONE) {
                                                    return DocResult(result.error, key_chain(key, sub_e.key));
                                                }
                                            }
                                            else static if (Document.Value.hasType!ElementT) {
                                                enum TypeE=Document.Value.asType!ElementT;
                                                if (TypeE !is sub_e.type) {
                                                    return DocResult(Document.Element.ErrorCode.ILLEGAL_TYPE, key_chain(key, sub_e.key));
                                                }
                                            }
                                            else static if (isInputRange!ElementT) {
                                                const sub_doc=sub_e.get!Document;
                                                const result=fitting(sub_doc);
                                                if (result.error !is Document.Element.ErrorCode.NONE) {
                                                    return DocResult(result.error, key_chain(key, sub_e.key));
                                                }
                                            }
                                            else {
                                                static assert(0, format("Type %s not supported", DocType.stringof));
                                            }
                                        }
                                        catch (Exception e) {
                                            return DocResult(Document.Element.ErrorCode.BAD_SUB_DOCUMENT, key_chain(key));
                                        }
                                    }
                                }
                                else static if (isAssociativeArray!DocType) {
                                    alias KeyTypeT=KeyType!DocType;
                                    alias ValueT=ValueType!DocType;
                                    static if (is(ValueT == enum)) {
                                        alias ElementT=TypedefType!(OriginalType!ValueT);
                                    }
                                    else {
                                        alias ElementT=TypedefType!(ValueT);
                                    }
                                    alias Key=CastTo!(KeyTypeT, AliasSeq!(const(string), const(uint)));
                                    static assert(!is(void==Key),
                                        format("Associated array with Key type for %s coan not be converted to HiBON", KeyTypeT.stringof));
                                    foreach(sub_e; doc[]) {
                                        static if (Document.Value.hasType!ElementT) {
                                            enum TypeE=Document.Value.asType!ElementT;
                                            if (TypeE !is sub_e.type) {
                                                return DocResult(Document.Element.ErrorCode.ILLEGAL_TYPE, key_chain(key, sub_e.key));
                                            }
                                        }
                                        else {
                                            enum TypeE=Document.Value.asType!Document;
                                            if (TypeE !is sub_e.type) {
                                                return DocResult(Document.Element.ErrorCode.ILLEGAL_TYPE, key_chain(key, sub_e.key));
                                            }
                                            try {
                                                const sub_doc=doc[key].get!Document;
                                                static if (isHiBON!FiledType) {
                                                    return FieldType.fitting(sub_doc, super_keys~key~sub_e.key);
                                                }
                                                else {
                                                }
                                            }
                                            catch (Exception e) {
                                                return DocResult(Document.Element.ErrorCode.BAD_SUB_DOCUMENT, key_chain(key));
                                            }
                                        }
                                    }
                                }
                                else {
                                    static assert(Document.Value.hasType!DocType,
                                        format("Type %s for member '%s' is not supported",
                                            FieldType.stringof, key));
                                    enum TypeE=Document.Value.asType!DocType;
                                    if (TypeE !is e.type) {
                                        return DocResult(Document.Element.ErrorCode.ILLEGAL_TYPE, key_chain(key));
                                    }
                                }
                                static if (key == TYPENAME) {
                                    if (this.type != e.get!string) {
                                        return DocResult(Document.Element.ErrorCode.DOCUMENT_TYPE, key_chain(key));
                                    }
                                }
                            }
                        }
                    }
                }
            default:
                return DocResult(Document.Element.ErrorCode.KEY_NOT_DEFINED, key_chain(null));
            }
        }
        return DocResult(Document.Element.ErrorCode.NONE,null);
    }

    enum keys=_keys;

    /++
     Returns:
     true if the Document members is confined to what is defined in object
     +/
    version(none)
    @safe
        static bool confined(const Document doc) nothrow {
        try {
            return fitting(doc).error is Document.Element.ErrorCode.NONE;
        }
        catch (Exception e) {
            return false;
        }
        assert(0);
    }



    static if (!NO_DEFAULT_CTOR) {
        @safe this(const HiBON hibon) {
            this(Document(hibon.serialize));
        }

        @safe this(const Document doc)  {
            static if (HAS_TYPE) {
                string _type=doc[TYPENAME].get!string;
                check(_type == type, format("Wrong %s type %s should be %s", TYPENAME, _type, type));
            }
            static if (hasUDA!(ThisType, RecordType)) {
                enum record=getUDAs!(ThisType, RecordType)[0];
                static if (record.code) {
                    scope(exit) {
                        mixin(record.code);
                    }
                }
            }
            static R toList(R)(const Document doc) {
                alias MemberU=ForeachType!(R);
                static if (is(MemberU == enum)) {
                    alias BaseU=TypedefType!(OriginaType!MemberU);
                }
                else {
                    alias BaseU=TypedefType!MemberU;
                }
                static if (isArray!R) {
                    alias UnqualU=Unqual!BaseU;
                    check(doc.isArray, format("Document is expected to be an array"));
                    UnqualU[] result;
                    result.length=doc.length;
                    enum do_foreach=true;
                }
                else static if (isAssociativeArray!R) {
                    R result;
                    enum do_foreach=true;
                }
                else {
                    return R(doc);
                    enum do_foreach=false;
                }
                static if (do_foreach) {
                    foreach(e; doc[]) {
                        static if (Document.Value.hasType!BaseU) {
                            auto value=e.get!BaseU;
                        }
                        else {
                            const sub_doc=e.get!Document;
                            static if (is(BaseU == struct)) {
                                auto value=BaseU(sub_doc);
                            }
                            else static if (is(BaseU == class)) {
                                auto value=new BaseU(sub_doc);
                            }
                            else static if (isInputRange!BaseU) {
                                auto value=toList!BaseU(sub_doc);
                            }
                            else {
                                static assert(0, format("Can not convert %s to Document", R.stringof));
                            }
                        }
                        static if (isAssociativeArray!R) {
                            result[e.key]=value;
                        }
                        else {
                            result[e.index]=value;
                        }
                    }
                }
                return result;
            }

            enum do_verify=hasMember!(typeof(this), "verify") && isCallable!(verify) && __traits(compiles, verify(doc));

            static if (do_verify) {
                scope(exit) {
                    check(this.verify(doc), format("Document verification faild"));
                }
            }

            alias ThisTuple=typeof(ThisType.tupleof);
        ForeachTuple:
            foreach(i, ref m; this.tupleof) {
                static if (__traits(compiles, typeof(m))) {
                    enum default_name=basename!(this.tupleof[i]);
                    static if (hasUDA!(this.tupleof[i], Label)) {
                        alias label=GetLabel!(this.tupleof[i]);
                        enum name=(label.name == VOID)?default_name:label.name;
                        enum optional=label.optional;
                        static if (label.optional) {
                            if (!doc.hasMember(name)) {
                                continue ForeachTuple;
                            }
                        }
                        static if (HAS_TYPE) {
                            static assert(TYPENAME != label.name,
                                format("Default %s is already definded to %s but is redefined for %s.%s",
                                    TYPENAME, TYPE, typeof(this).stringof, basename!(this.tupleof[i])));
                        }
                    }
                    else {
                        enum name=default_name;
                        enum optional=false;
                    }
                    static if(hasUDA!(this.tupleof[i], Assign)) {
                        alias assigns=getUDAs!(this.tupleof[i], Assign);
                        static assert(assigns.length is 1, "Only one Assignn UDA allowed per member");
                        alias assignFun=unaryFun!(assigns[0].code);
                        auto x=assignFun(doc);
                        this.tupleof[i]=assignFun(doc);
                    }
                    else static if (name.length) {
                        enum member_name=this.tupleof[i].stringof;
                        //  enum code=format("%s=doc[name].get!UnqualT;", member_name);
                        alias MemberT=typeof(m);
                        static if (is(MemnerT == enum)) {
                            alias BaseT=TypedefType!(OriginaType!MemberT);
                        }
                        else {
                            alias BaseT=TypedefType!MemberT;
                        }
                        alias UnqualT=Unqual!BaseT;
                        static if (optional) {
                            if (!doc.hasMember(name)) {
                                continue ForeachTuple;
                            }
                        }
                        static if (hasUDA!(this.tupleof[i], Inspect)) {
                            alias Inspects=getUDAs!(this.tupleof[i], Inspect);
                            scope(exit) {
                                static foreach(F; Inspects) {
                                    {
                                        alias inspectFun=unaryFun!(F.code);
                                        check(inspectFun(m), message("Member %s faild on inspection %s with %s", name, F.code, m));
                                    }
                                }
                            }

                        }
                        static if (Document.Value.hasType!BaseT) {
                            m=doc[name].get!BaseT;
                        }
                        else static if (is(BaseT == struct)) {
                            auto sub_doc = doc[name].get!Document;
                            m=BaseT(sub_doc);
                        }
                        else static if (is(BaseT == class)) {
                            const sub_doc = Document(doc[name].get!Document);
                            m=new BaseT(sub_doc);
                        }
                        // else static if (isAssociativeArray!BaseT) {
                        //     Document sub_doc;
                        //     if (doc.hasMember(name)) {
                        //         sub_doc = Document(doc[name].get!Document);
                        //     }
                        //     m=toList!BaseT(sub_doc);
                        // }
                        else static if (isInputRange!BaseT || isAssociativeArray!BaseT) {
                            Document sub_doc;
                            if (doc.hasMember(name)) {
                                sub_doc = Document(doc[name].get!Document);
                            }
                            m=toList!BaseT(sub_doc);
                        }
                        // else static if (isHiBONRecor!BaseT) {

                        // }
                        else static if (isHiBONRecordArray!BaseT) {
                            const doc_array=doc[name].get!Document;
                            check(doc_array.isArray, message("Document array expected for %s member",  name));
                            UnqualT result() @trusted {
                                UnqualT array;
                                alias ElementT=ForeachType!UnqualT;

                                array.length=doc_array.length;
                                foreach(ref a, e; lockstep(array, doc_array[])) {
                                    a=e.get!ElementT;
                                }
                                return array;
                            }
                            m=result;
                        }
                        else {
                            static assert(0, format("Convering for member '%s' of type %s is not supported by default", name, MemberT.stringof));

                        }
//                         else static if (isInputRange!BaseT) {

//                         }
//                         else static if (is(BaseT:U[], U)) {
//                             static if (hasMember!(U, "toHiBON")) {
//                                 MemberT array;
//                                 const doc_array=doc[name].get!Document;
//                                 static if (optional) {
//                                     if (doc_array.length == 0) {
//                                         continue ForeachTuple;
//                                     }
//                                 }
//                                 check(doc_array.isArray, message("Document array expected for %s member",  name));
//                                 foreach(e; doc_array[]) {
//                                     const sub_doc=e.get!Document;
//                                     array~=U(sub_doc);
//                                 }
//                                 enum doc_array_code=format("%s=array;", member_name);
//                                 mixin(doc_array_code);
//                             }
//                             else static if (Document.Value.hasType!U) {
//                                 MemberT array;
//                                 auto doc_array=doc[name].get!Document;
//                                 static if (optional) {
//                                     if (doc_array.length == 0) {
//                                         continue ForeachTuple;
//                                     }
//                                 }
//                                 check(doc_array.isArray, message("Document array expected for %s member",  name));
//                                 foreach(e; doc_array[]) {
//                                     array~=e.get!U;
//                                 }
//                                 m=array;
//                             }
//                             else static if (is(U == immutable)) {
//                                 enum code=q{m=doc[name].get!BaseT;};
//                                 m=doc[name].get!BaseT;
//                             }
//                             else {
//                                 alias InvalidType=immutable(U)[];
//                                 static assert(0, format("The array must be immutable not %s but is %s %s %s",
//                                         BaseT.stringof, InvalidType.stringof, U.stringof, is(U == immutable)));
//                                 enum code="";
//                             }
//                         }
//                         else static if (Document.Value.hasType!BaseT) {
// //                          enum code=q{this.tupleof[i]=doc[name].get!UnqualT;};
//                             m=doc[name].get!UnqualT;
//                         }

                    }
                }
                else {
                    static assert(0,
                        format("Type %s for member %s is not supported", BaseT.stringof, name));
                    enum code="";
                }
                // else {
                //     enum code="";
                // }
                // static if (code.length) {
                //     mixin(code);
                // }
            }
        }
    }

    final const(Document) toDoc() const {
        return Document(toHiBON.serialize);
    }
}

/++
 Serialize the hibon and writes it a file
 Params:
 filename = is the name of the file
 hibon = is the HiBON object
 +/
@safe
void fwrite(string filename, const HiBON hibon) {
    file.write(filename, hibon.serialize);
}


/++
 Reads a HiBON document from a file
 Params:
 filename = is the name of the file
 Returns:
 The Document read from the file
 +/
@trusted
const(Document) fread(string filename) {
    import tagion.hibon.HiBONException : check;
    immutable data=assumeUnique(cast(ubyte[])file.read(filename));
    const doc=Document(data);
    check(doc.isInorder, "HiBON Document format failed");
    return doc;
}

@safe
unittest {
//    import std.stdio;
    import std.format;
    import std.exception : assertThrown, assertNotThrown;
    import std.traits : OriginalType, staticMap, Unqual;
    import std.meta : AliasSeq;
    import std.range : lockstep;
    import std.algorithm.comparison : equal;
    import tagion.hibon.HiBONException : HiBONException, HiBONRecordException;

    @RecordType("SIMPEL") static struct Simpel {
        int s;
        string text;
        mixin HiBONRecord!(
            q{
                this(int s, string text) {
                    this.s=s; this.text=text;
                }
            }
            );

    }

    @RecordType("SIMPELLABEL") static struct SimpelLabel {
        @Label("$S") int s;
        @Label("TEXT") string text;
        mixin HiBONRecord!(
            q{
                this(int s, string text) {
                    this.s=s; this.text=text;
                }
            });
    }

    @RecordType("BASIC") static struct BasicData {
        int i32;
        uint u32;
        long i64;
        ulong u64;
        float f32;
        double f64;
        string text;
        bool flag;
        mixin HiBONRecord!(
            q{this(int i32,
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

    template SimpelOption(string LABEL="") {
        @RecordType(LABEL)
        static struct SimpelOption {
            int not_an_option;
            @Label("s", true) int s;
            @Label(VOID, true) string text;
            mixin HiBONRecord!();
        }
    }


    { // Simpel basic type check
        {
            const s=Simpel(-42, "some text");
            const docS=s.toDoc;
            // writefln("keys=%s", docS.keys);
            assert(docS["s"].get!int == -42);
            assert(docS["text"].get!string == "some text");
            assert(docS[TYPENAME].get!string == Simpel.type);
            const s_check=Simpel(docS);
            // const s_check=Simpel(s);
            assert(s == s_check);
            assert(s_check.toJSON.toString == format("%j", s_check));
        }

        {
            const s=SimpelLabel(42, "other text");
            const docS=s.toDoc;
            assert(docS["$S"].get!int == 42);
            assert(docS["TEXT"].get!string == "other text");
            assert(docS[TYPENAME].get!string == SimpelLabel.type);
            const s_check=SimpelLabel(docS);

            assert(s == s_check);

            immutable s_imut = SimpelLabel(docS);
            assert(s_imut == s_check);
        }

        {
            const s=BasicData(-42, 42, -42_000_000_000UL, 42_000_000_000L, 42.42e-9, -42.42e-300, "text", true);
            const docS=s.toDoc;

            const s_check=BasicData(docS);

            assert(s == s_check);
            immutable s_imut = BasicData(docS);
            assert(s_imut == s_check);
        }
    }

    { // Check option
        alias NoLabel=SimpelOption!("");
        alias WithLabel=SimpelOption!("LBL");

        { // Empty document
            auto h=new HiBON;
            const doc=Document(h.serialize);
//            writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertThrown!HiBONException(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));
        }

        {
            auto h=new HiBON;
            h["not_an_option"]=42;
            const doc=Document(h.serialize);
            //          writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!Exception(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));
        }

        {
            auto h=new HiBON;
            h["not_an_option"]=42;
            h[TYPENAME]="LBL";
            const doc=Document(h.serialize);
            //  writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!Exception(NoLabel(doc));
            assertNotThrown!Exception(WithLabel(doc));
        }

        {
            NoLabel s;
            s.not_an_option=42;
            s.s =17;
            s.text="text!";
            const doc=s.toDoc;
            // writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!Exception(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));

            auto h=s.toHiBON;
            h[TYPENAME]=WithLabel.type;
            const doc_label=Document(h.serialize);
            // writefln("docS=\n%s", doc_label.toJSON(true).toPrettyString);

            const s_label=WithLabel(doc_label);
            // writefln("docS=\n%s", s_label.toDoc.toJSON(true).toPrettyString);

            const s_new=NoLabel(s_label.toDoc);

        }
    }

    { // Check verify member
        template NotBoth(bool FILTER) {
            @RecordType("NotBoth") static struct NotBoth {
                static if (FILTER) {
                    @Label("*", true) @(Filter.Initialized) int x;
                    @Label("*", true) @(Filter.Initialized) @Filter(q{a < 42}) int y;
                }
                else {
                    @Label("*", true) int x;
                    @Label("*", true) int y;
                }
                bool verify(const Document doc) {
                    return doc.hasMember("x") ^ doc.hasMember("y");
                }
                mixin HiBONRecord!(
                    q{
                        this(int x, int y) {
                            this.x=x; this.y=y;
                        }
                    });
            }
        }

        alias NotBothFilter=NotBoth!true;
        alias NotBothNoFilter=NotBoth!false;

        const s_filter_x=NotBothFilter(11, int.init);
        const s_filter_y=NotBothFilter(int.init, 13);
        const s_dont_filter=NotBothFilter();
        const s_dont_filter_xy=NotBothFilter(11, 13);

        const s_filter_x_doc=s_filter_x.toDoc;
        const s_filter_y_doc=s_filter_y.toDoc;
        const s_dont_filter_doc=s_dont_filter.toDoc;
        const s_dont_filter_xy_doc=s_dont_filter_xy.toDoc;

        // writefln("docS=\n%s", s_filter_x.toDoc.toJSON(true).toPrettyString);
        // writefln("docS=\n%s", s_filter_y.toDoc.toJSON(true).toPrettyString);
        {
            const check_s_filter_x=NotBothFilter(s_filter_x_doc);
            assert(check_s_filter_x == s_filter_x);
            const check_s_filter_y=NotBothFilter(s_filter_y_doc);
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
        @safe
            static struct SuperStruct {
            Simpel sub;
            string some_text;
            mixin HiBONRecord!(
                q{
                    this(string some_text, int s, string text) {
                        this.some_text=some_text;
                        sub=Simpel(s, text);
                    }
                });
        }
        const s=SuperStruct("some_text", 42, "text");
        const s_converted=SuperStruct(s.toDoc);
        assert(s == s_converted);
    }

    {
        @safe
            static class SuperClass {
            Simpel sub;
            string class_some_text;
            mixin HiBONRecord!(
                q{
                    this(string some_text, int s, string text) {
                        this.class_some_text=some_text;
                        sub=Simpel(s, text);
                    }
                });
            bool opEqual(const SuperClass lhs) const pure nothrow {
                return true;
            }
        }
        const s=new SuperClass("some_text", 42, "text");
        const s_converted=new SuperClass(s.toDoc);
        assert(s.toDoc == s_converted.toDoc);
    }

    {
        static struct Test {
            @Inspect(q{a < 42}) @Inspect(q{a > 3}) int x;
            mixin HiBONRecord;
        }

        Test s;
        s.x=17;
        assertNotThrown!Exception(Test(s.toDoc));
        s.x=42;
        assertThrown!HiBONRecordException(Test(s.toDoc));
        s.x=1;
        assertThrown!HiBONRecordException(Test(s.toDoc));

    }

    { // Element as range
        @safe
            static struct Range(T) {
            alias UnqualT=Unqual!T;
            protected T[] array;
            @nogc this(T[] array) {
                this.array=array;
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
                        array=array[1..$];
                    }
                }
            }

            version(none)
            static if (isHiBON!T) {
                static DocResult fitting(const Document doc, const(string[]) key_chain) nothrow {
                    if (!doc.isArray) {
                        return DocResult(Document.Element.ErrorCode.NOT_AN_ARRAY,null);
                    }
                    foreach(e; doc[]) {
                        const result=T.fitting(doc);
                        if (result.error !is Document.Element.ErrorCode.NONE) {
                            return result;
                        }
                    }
                    return DocResult(Document.Element.ErrorCode.NONE,null);
                }
            }
            else {
                static DocResult fitting(const Document doc, const(string[]) key_chain) nothrow {
                    static assert(Document.Value.hasType!UnqualT);
                    enum TypeE=Document.Value.asType!UnqualT;
                    foreach(e; doc[]) {
                        if (e.type !is TypeE) {
                            return DocResult(Document.Element.ErrorCode.ILLEGAL_TYPE,e.key);
                        }
                    }
                    return DocResult(Document.Element.ErrorCode.NONE,null);
                }
            }

            @trusted
            this(const Document doc) {
                auto result=new UnqualT[doc.length];
                foreach(ref a, e; lockstep(result, doc[])) {
                    a=e.get!T;
                }
                array=result;
            }
        }

        @safe
            auto StructWithRangeTest(T)(T[] array) {
            alias R=Range!T;
            @safe
                static struct StructWithRange {
                R range;
                static assert(isInputRange!R);
                mixin HiBONRecord!(
                    q{
                        this(T[] array) {
                            this.range=R(array);
                        }
                    });
            }
            return StructWithRange(array);
        }

        { // Simple Range
            const(int)[] array = [-42, 3, 17];
            const s=StructWithRangeTest(array);
            //writefln("s=%s",s);
            //writefln("doc=%s", s.toJSON.toPrettyString);
            const doc=s.toDoc;
            alias ResultT=typeof(s);
            //assert(ResultT.fitting(doc).error is Document.Element.ErrorCode.NONE);
            const s_doc=ResultT(doc);

            //writefln("s_doc=%s", s_doc);
            assert(s_doc == s);
        }

        {  // Range of structs
            Simpel[] simpels;
            simpels~=Simpel(1, "one");
            simpels~=Simpel(2, "two");
            simpels~=Simpel(3, "three");
            {
                auto s=StructWithRangeTest(simpels);
                alias StructWithRange=typeof(s);
                {
                    auto h=new HiBON;
                    h["s"]=s;

                    const s_get=h["s"].get!StructWithRange;
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
                    auto h=new HiBON;
                    h["s"]=s;
                    const s_get=h["s"].get!SimpelArray;
                    assert(s_get == s);
                }
                {
                    SimpelArray s;
                    s.array=simpels;
                    auto h=new HiBON;
                    h["s"]=s;

                    const s_get=h["s"].get!SimpelArray;

                    // @trusted void dump() {
                    //     writefln("h=%J", h);
                    // }
                    // dump();
                    assert(s_get == s);
                    const s_doc=s_get.toDoc;

                    const s_array=s_doc["array"].get!(Simpel[]);
                    assert(equal(s_array, s.array));

                    const s_result=SimpelArray(s_doc);
                    assert(s_result == s);
                }
            }
        }
        { // Jagged Array
            @safe
            static struct Jagged {
                Simpel[][] y;
                mixin HiBONRecord;
            }

            Simpel[][] ragged = [
                [ Simpel(1, "one"), Simpel(2, "one")],
                [ Simpel(1, "two"), Simpel(2, "two"), Simpel(3, "two")],
                [ Simpel(1, "three")]
                ];

            //writefln("%s", ragged);
            Jagged jagged;
            jagged.y=ragged;

            const jagged_doc=jagged.toDoc;
// //            (() @trusted {
//                 writefln("%J", jagged);
//             })();

            const result=Jagged(jagged_doc);
            // (() @trusted {
            //     writefln("%J", result);
            // })();

            assert(jagged == result);
        }

        {
            @safe
            static struct Associative {
                Simpel[string] a;
                mixin HiBONRecord;
            }

            Associative associative;
            associative.a["$one"]=Simpel(1, "one");
            associative.a["$two"]=Simpel(1, "two");
            associative.a["$three"]=Simpel(1, "three");

            // writefln("%J", associative);

            const associative_doc=associative.toDoc;

            const result=Associative(associative_doc);
            // (() @trusted {
            //     writefln("%J", result);
            //     foreach(key, e; result.a) {
            //         writefln("key=%s %j", key, e);
            //     }
            //     foreach(key, e; associative.a) {
            //         writefln("key=%s %j", key, e);
            //     }
            //     writefln("%s", result.a.keys);
            //     writefln("%s", associative.a.keys);
            //     writefln("%s", result.a.byValue);
            //     writefln("%s", associative.a.byValue);
            //     assert(equal(result.a.keys, associative.a.keys));
            // })();


            // result.a.each!(writeln);
            // writefln("%s", result.a[]);
            // writefln("%s", associative.a[]);
//            assert(equal(result.a, associative.a));
            (() @trusted {

                assert(equal(result.a.keys, associative.a.keys));
                assert(equal(result.a.byValue, associative.a.byValue));
            })();

            // writefln("%j", result);
        }

    }

}
