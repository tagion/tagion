module tagion.hibon.HiBONRecord;

import file=std.file;
import std.exception : assumeUnique;

import tagion.basic.Basic : basename;
import tagion.hibon.HiBONBase : ValueT;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONException;

/++
 Label use to set the HiBON member name
 +/
struct Label {
    string name;   /// Name of the HiBON member
    bool optional; /// This flag is set to true if this paramer is optional

}
struct Inspect {
    string verify; ///
}

/++
 Gets the Label for HiBON member
 Params:
 member = is the member alias
 +/
template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;
    static if (hasUDA!(member, Label)) {
        enum GetLabel=getUDAs!(member, Label);
    }
    else {
        enum GetLabel=Label(basename!(member));
    }
}

enum HiBONPrefix {
    HASH = '#',
    PARAM = '$'
}

enum TYPENAME=HiBONPrefix.PARAM~"@";
enum VOID="*";
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
mixin template HiBONRecord(string TYPE="", string CTOR="") {

    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual, hasMember;
    import std.typecons : TypedefType, Tuple;
    import std.format;
    import std.functional : unaryFun;
    import std.range : iota;
    import std.meta : staticMap;

    import tagion.hibon.HiBONException : check;
    import tagion.basic.Message : message;
    import tagion.basic.Basic : basename;

    static if (TYPE.length) {
        static string type() pure nothrow {
            return TYPE;
        }
    }

    inout(HiBON) toHiBON() inout {
        auto hibon= new HiBON;
        pragma(msg, typeof(this.tupleof), " ", this.tupleof.length);
        foreach(i, m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                enum default_name=basename!(this.tupleof[i]);
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i])[0];
                    enum name=(label.name == VOID)?default_name:label.name;
                }
                else {
                    enum name=basename!(this.tupleof[i]);
                }
                static if (name.length) {
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    static if (__traits(compiles, m.toHiBON)) {
                        hibon[name]=m.toHiBON;
                    }
                    else static if (is(MemberT == enum)) {
                        hibon[name]=cast(OriginalType!MemberT)m;
                    }
                    else static if (is(BaseT == class) || is(BaseT == struct)) {
                        static assert(is(BaseT == HiBON) || is(BaseT : const(Document)),
                            format(`A sub class/struct %s must have a toHiBON or must be ingnored will @Label("") UDA tag`, name));
                        hibon[name]=cast(BaseT)m;
                    }
                    else {
                        static if (is(BaseT:U[], U)) {
                            static if (HiBON.Value.hasType!U) {
                                // static assert(0, format("Special handeling of array %s", MemberT.stringof));
                                auto array=new HiBON;
                                foreach(index, e; cast(BaseT)m) {
                                    array[index]=e;
                                }
                                hibon[name]=array;
                            }
                            else static if (hasMember!(U, "toHiBON")) {
                                auto array=new HiBON;
                                foreach(index, e; cast(BaseT)m) {
                                    array[index]=e.toHiBON;
                                }
                                hibon[name]=array;
                            }
                            else {
                                static assert(is(U == immutable), format("The array must be immutable not %s but is %s",
                                        BaseT.stringof, (immutable(U)[]).stringof));
                                hibon[name]=cast(BaseT)m;
                            }
                        }
                        else {
                            pragma(msg, "->", BaseT, ": ", MemberT, ": ", i, "m=", m.stringof, " ", typeof(this.tupleof[i]), " ", this.tupleof[i].stringof);
                            hibon[name]=cast(BaseT)m;
                        }
                    }
                }
            }
        }
        static if (TYPE.length) {
            hibon[TYPENAME]=TYPE;
        }
        return cast(inout)hibon;
    }

    /++
     Constructors must be mixed in or else the default construction is will be removed
     +/
    static if (CTOR.length) {
        mixin(CTOR);
    }

    alias ThisType=typeof(this);
    import std.traits : FieldNameTuple, Fields;

    // protected static void check_key(string key) {
    // SwitchKey:
    //     switch (key) {
    //         static foreach(i, M, FieldNameTuple!ThisType) {
    //         case M:

    //             break SwitckKey;
    //         }
    //     default:

    //     }
    // }
    template GetKeyName(uint i) {
        enum default_name=basename!(this.tupleof[i]);
        static if (hasUDA!(this.tupleof[i], Label)) {
            alias label=GetLabel!(this.tupleof[i])[0];
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
        alias ThisTuple=typeof(this.tupleof);
        static foreach(i; 0..ThisTuple.length) {
            result~=GetKeyName!i;
        }
        return result;
    }

    alias DocResult=Tuple!(Document.Element.ErrorCode, "error", string , "key");
    /++
     Check if the Documet is fitting the object
     Returns:
     If the Document fits compleatly it returns NONE
     +/
    static DocResult fitting(const Document doc) nothrow {
        foreach(e; doc[]) {
            switch (e.key) {
                static foreach(i, key; keys) {
                    {
                    alias Type=Fields!ThisType[i];
                case key:
                    static assert(Document.Value.hasType!Type,
                        format("Type %s for member %s with key %s is not supported",
                            Type.stringof, FieldsNameTuple!ThisType[i], key));
                    enum TypeE=Document.Value.asType!Type;
                    if (TypeE !is e.type) {
                        return DocResult(Document.Element.ErrorCode.ILLEGAL_TYPE, key);
                    }
                    static if (key == TYPENAME) {
                        if (this.type != e.get!string) {
                            return DocResult(Document.Element.ErrorCode.DOCUMENT_TYPE, key);
                        }
                    }
                    }
                }
            default:
                return DocResult(Document.Element.ErrorCode.KEY_NOT_DEFINED, e.key);
            }
        }
        return DocResult(Document.Element.ErrorCode.NONE,null);
    }

    enum keys=_keys;

    /++
     Returns:
     true if the Document members is confined to what is defined in object
     +/
//    @nogc
    static bool confined(const Document doc) nothrow {
        try {
            return fitting(doc).error is Document.Element.ErrorCode.NONE;
        }
        catch (Exception e) {
            return false;
        }
        assert(0);
    }

    this(const Document doc) {
        static if (TYPE.length) {
            string _type=doc[TYPENAME].get!string;
            .check(_type == type, format("Wrong %s type %s should be %s", TYPENAME, _type, type));
        }
        enum do_verify=hasMember!(typeof(this), "verify") && isCallable(verify);
        static if (do_verify) {
            scope(exit) {
                this.verify;
            }
        }
    ForeachTuple:
        foreach(i, ref m; this.tupleof) {
//            pragma(msg, m);
            static if (__traits(compiles, typeof(m))) {
                enum default_name=basename!(this.tupleof[i]);
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i])[0];
                    pragma(msg, "label.name=", label.name, " VOID=", VOID, " default_name=", default_name);
                    enum name=(label.name == VOID)?default_name:label.name;
                    pragma(msg, "* name=", name);
                    enum optional=label.optional;
                    static if (label.optional) {
                        if (!doc.hasElement(name)) {
                            break ForeachTuple;
                        }
                    }
                    static if (TYPE.length) {
                        static assert(TYPENAME != label.name,
                            format("Default %s is already definded to %s but is redefined for %s.%s",
                                TYPENAME, TYPE, typeof(this).stringof, basename!(this.tupleof[i])));
                    }
                }
                else {
                    enum name=default_name;
                    enum optional=false;
                }
                static if (hasUDA!(this.tupleof[i], Inspect)) {
                    alias Inspects=getUDAs!(m, Inspect);

                    pragma(msg, Inspects);
                }
                static if (name.length) {
                    enum member_name=this.tupleof[i].stringof;
                    //  enum code=format("%s=doc[name].get!UnqualT;", member_name);
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    alias UnqualT=Unqual!BaseT;
                    pragma(msg, MemberT, ": ", BaseT, ": ", UnqualT);
                    static if (is(BaseT == struct)) {
                        auto sub_doc = doc[name].get!Document;
                        m=BaseT(sub_doc);
                        // enum doc_code=format("%s=BaseT(dub_doc);", member_name);
                        // mixin(doc_code);
                    }
                    else static if (is(BaseT == class)) {
                        const dub_doc = Document(doc[name].get!Document);
                        m=new BaseT(dub_doc);
                    }
                    else static if (is(BaseT == enum)) {
                        alias EnumBaseT=OriginalType!BaseT;
                        m=cast(BaseT)doc[name].get!EnumBaseT;
                    }
                    else static if (is(BaseT:U[], U)) {
                        static if (hasMember!(U, "toHiBON")) {
                            MemberT array;
                            auto doc_array=doc[name].get!Document;
                            static if (optional) {
                                if (doc_array.length == 0) {
                                    continue ForeachTuple;
                                }
                            }
                            check(doc_array.isArray, message("Document array expected for %s member",  name));
                            foreach(e; doc_array[]) {
                                const sub_doc=e.get!Document;
                                array~=U(sub_doc);
                            }
                            enum doc_array_code=format("%s=array;", member_name);
                            mixin(doc_array_code);
                        }
                        else static if (Document.Value.hasType!U) {
                            MemberT array;
                            auto doc_array=doc[name].get!Document;
                            static if (optional) {
                                if (doc_array.length == 0) {
                                    continue ForeachTuple;
                                }
                            }
                            check(doc_array.isArray, message("Document array expected for %s member",  name));
                            foreach(e; doc_array[]) {
                                array~=e.get!U;
                            }
                            m=array;
//                                static assert(0, format("Special handling of array %s", MemberT.stringof));
                        }
                        else static if (is(U == immutable)) {
                            // static assert(is(U == immutable), format("The array must be immutable not %s but is %s",
                            //         BaseT.stringof, cast(immutable(U)[]).stringof));
                            enum code=q{m=doc[name].get!BaseT;};
                            pragma(msg, "code=", code, " ", typeof(m), " ", m.stringof);
                            m=doc[name].get!BaseT;
//                            mixin(code);
                        }
                        else {
                            alias InvalidType=immutable(U)[];
                            static assert(0, format("The array must be immutable not %s but is %s %s %s",
                                    BaseT.stringof, InvalidType.stringof, U.stringof, is(U == immutable)));
                            enum code="";
                        }
                    }
                    else static if (Document.Value.hasType!BaseT) {
                        enum code=q{this.tupleof[i]=doc[name].get!UnqualT;};
                        m=doc[name].get!UnqualT;
                    }
//                    }
                    // else {
                    //     pragma(msg, "code=", code, " ", typeof(m));
                    //     //this.tupleof[i]=doc[name].get!UnqualT;
                    //     //mixin(code);
                    // }
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

    const(Document) toDoc() const {
        return Document(toHiBON.serialize);
    }
}

/++
 Serialize the hibon and writes it a file
 Params:
 filename = is the name of the file
 hibon = is the HiBON object
 +/
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
const(Document) fread(string filename) {
    immutable data=assumeUnique(cast(ubyte[])file.read(filename));
    const doc=Document(data);
    .check(doc.isInorder, "HiBON Document format failed");
    return doc;
}

unittest {
    import std.stdio;
    import std.format;
    import std.exception : assertThrown, assertNotThrown;
    import tagion.hibon.HiBONJSON;
        static struct Simpel {
            int s;
            string text;
            mixin HiBONRecord!("SIMPEL",
                q{
                    this(int s, string text) {
                        this.s=s; this.text=text;
                    }
                }
                );

        }

        static struct SimpelLabel {
            @Label("$S") int s;
            @Label("TEXT") string text;
            mixin HiBONRecord!("SIMPELLABEL",
                q{
                    this(int s, string text) {
                        this.s=s; this.text=text;
                    }
                });
        }

        static struct BasicData {
            int i32;
            uint u32;
            long i64;
            ulong u64;
            float f32;
            double f64;
            string text;
            bool flag;
            mixin HiBONRecord!("BASIC",
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

        static struct SimpelOption(string LABEL="") {
            int not_an_option;
            @Label("s", true) int s;
            @Label(VOID, true) string text;
            mixin HiBONRecord!(LABEL);
        }


    // string Assert(string code)() {
    //     import std.stdio;
    //     return format(
    //         q{
    //             try {
    //                 %s;
    //                 writeln("Expected to fail");
    //             }
    //             catch (HiBONException e) {
    //                 return true;
    //                 // Ok
    //             }
    //             catch (Throwable e) {
    //                 writefln("Expected to throw an HiBONException not %%s", e);
    //             }
    //             return false;
    //         },
    //         code
    //         );
    //     assert(0);
    // }



    { // Simpel basic type check
        {
            const s=Simpel(-42, "some text");
            const docS=s.toDoc;
            writefln("keys=%s", docS.keys);
            assert(docS["s"].get!int == -42);
            assert(docS["text"].get!string == "some text");
            assert(docS[TYPENAME].get!string == "SIMPEL");
            writefln("docS=\n%s", docS.toJSON(true).toPrettyString);
            pragma(msg, "type docS=", typeof(docS));
            const s_check=Simpel(docS);
            writefln("docS=\n%s", s_check.toDoc.toJSON(true).toPrettyString);
            // const s_check=Simpel(s);
            assert(s == s_check);
        }

        {
            const s=SimpelLabel(42, "other text");
            const docS=s.toDoc;
            writefln("keys=%s", docS.keys);
            assert(docS["$S"].get!int == 42);
            assert(docS["TEXT"].get!string == "other text");
            assert(docS[TYPENAME].get!string == "SIMPELLABEL");
            const s_check=SimpelLabel(docS);
            writefln("docS=\n%s", s_check.toDoc.toJSON(true).toPrettyString);


            assert(s == s_check);

            immutable s_imut = SimpelLabel(docS);
            assert(s_imut == s_check);
        }

        {
            const s=BasicData(-42, 42, -42_000_000_000UL, 42_000_000_000L, 42.42e-9, -42.42e-300, "text", true);
            const docS=s.toDoc;

            const s_check=BasicData(docS);
            writefln("docS=\n%s", s_check.toDoc.toJSON(true).toPrettyString);

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
            writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertThrown!HiBONException(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));
        }

        {
            auto h=new HiBON;
            h["not_an_option"]=42;
            const doc=Document(h.serialize);
            writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!HiBONException(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));
        }

        {
            auto h=new HiBON;
            h["not_an_option"]=42;
            h[TYPENAME]="LBL";
            const doc=Document(h.serialize);
            writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!HiBONException(NoLabel(doc));
            assertNotThrown!HiBONException(WithLabel(doc));
        }

        {
            NoLabel s;
            s.not_an_option=42;
            s.s =17;
            s.text="text!";
            const doc=s.toDoc;
            writefln("docS=\n%s", doc.toJSON(true).toPrettyString);
            assertNotThrown!HiBONException(NoLabel(doc));
            assertThrown!HiBONException(WithLabel(doc));

            auto h=s.toHiBON;
            h[TYPENAME]=WithLabel.type;
            const doc_label=Document(h.serialize);
            writefln("docS=\n%s", doc_label.toJSON(true).toPrettyString);

            const s_label=WithLabel(doc_label);
            writefln("docS=\n%s", s_label.toDoc.toJSON(true).toPrettyString);

            const s_new=NoLabel(s_label.toDoc);

            // WithLabel s_label;
            // s_label.not_an_option=s.not_an_option;
            // s_label.s=s.s;

        }
    }

}
