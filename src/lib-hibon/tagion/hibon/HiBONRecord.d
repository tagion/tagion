module tagion.hibon.HiBONRecord;

import file=std.file;
import std.exception : assumeUnique;

import tagion.basic.Basic : basename, EnumContinuousSequency;
import tagion.hibon.HiBONBase : ValueT;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONException : HiBONRecordException;



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


struct Inspect {
    string verify; ///
}

struct RecordType {
    string name;
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

    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual, hasMember, isCallable, EnumMembers;
    import std.typecons : TypedefType, Tuple;
    import std.format;
    import std.functional : unaryFun;
    import std.range : iota;
    import std.meta : staticMap;

//    import tagion.hibon.HiBONException : check;
    import tagion.basic.Message : message;
    import tagion.basic.Basic : basename;
    import tagion.basic.TagionExceptions : Check;
    alias check=Check!(HiBONRecordException);

    alias ThisType=typeof(this);

    static if (hasUDA!(ThisType, RecordType)) {
        alias record_types=getUDAs!(ThisType, RecordType);
        static assert(record_types.length is 1, "Only one RecordType UDA allowed");
        static if (record_types[0].name.length) {
            enum type=record_types[0].name;
        }
    }

    enum HAS_TYPE=hasMember!(ThisType, "type");

    inout(HiBON) toHiBON() inout {
        auto hibon= new HiBON;
        pragma(msg, typeof(this.tupleof), " ", this.tupleof.length);
    MemberLoop:
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
                static if (hasUDA!(this.tupleof[i], Filter)) {
                    alias filters=getUDAs!(this.tupleof[i], Filter);
                    pragma(msg, "FILTERS=", filters);
                    static foreach(F; filters) {
                        {
                            alias filterFun=unaryFun!(F.code);
                            pragma(msg, filterFun.stringof);
                            if (!filterFun(m)) {
                                continue MemberLoop;
                            }
                        }
                    }
                }
                static if (name.length) {
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    alias UnqualT=Unqual!BaseT;
                    writefln("IS ENUM %s", is(MemberT == enum));
                    static if (__traits(compiles, m.toHiBON)) {
                        hibon[name]=m.toHiBON;
                    }
                    else static if (is(MemberT == enum)) {
                        hibon[name]=cast(OriginalType!MemberT)m;
                        writefln("ENUM name %s type=%s MemberT=%s OriginalType!MemberT=%s",
                            name, hibon[name].type, MemberT.stringof, OriginalType!MemberT.stringof);
                    }
                    else static if (is(BaseT == class) || is(BaseT == struct)) {
                        static assert(is(BaseT == HiBON) || is(BaseT : const(Document)),
                            format(`A sub class/struct %s must have a toHiBON or must be ingnored will @Label("") UDA tag`, name));
                        hibon[name]=cast(BaseT)m;
                    }
                    else {
                        static if (is(BaseT:U[], U)) {
                            // scope(exit) {
                            //     writefln("set %s %s", name, m);
                            // }

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
                            scope(exit) {
                                writefln("set %s %s", name, cast(UnqualT)(this.tupleof[i]));
                            }

                            hibon[name]=cast(BaseT)m;
                        }
                    }
                }
            }
        }
        static if (HAS_TYPE) {
            hibon[TYPENAME]=type;
        }
        return cast(inout)hibon;
    }

    /++
     Constructors must be mixed in or else the default construction is will be removed
     +/
    static if (CTOR.length) {
        mixin(CTOR);
    }


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
                        alias FieldType=Fields!ThisType[i];
                        case key:
                            static if (is(FieldType == enum)) {
                                alias DocType=OriginalType!FieldType;
                            }
                            else {
                                alias DocType=FieldType;
                            }
                            static assert(Document.Value.hasType!DocType,
                                format("Type %s for member %s with key %s is not supported",
                                    Type.stringof, DocType, key));
                            enum TypeE=Document.Value.asType!DocType;
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
        static if (HAS_TYPE) {
            string _type=doc[TYPENAME].get!string;
            check(_type == type, format("Wrong %s type %s should be %s", TYPENAME, _type, type));
        }
        enum do_verify=hasMember!(typeof(this), "verify") && isCallable!(verify);
        static if (do_verify) {
            scope(exit) {
                check(this.verify(doc), format("Document verification faild"));
            }
        }
    ForeachTuple:
        foreach(i, ref m; this.tupleof) {
//            pragma(msg, m);
            static if (__traits(compiles, typeof(m))) {
                enum default_name=basename!(this.tupleof[i]);
                writefln("default_name=%s", default_name);
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i])[0];
                    pragma(msg, "label.name=", label.name, " VOID=", VOID, " default_name=", default_name);
                    enum name=(label.name == VOID)?default_name:label.name;
                    pragma(msg, "* name=", name);
                    enum optional=label.optional;
                    writefln("\toptional=%s", optional, doc.hasMember(name));
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
                static if (hasUDA!(this.tupleof[i], Inspect)) {
                    alias Inspects=getUDAs!(m, Inspect);

                    pragma(msg, Inspects);
                }
                writefln("\tname=%s", name);
                static if (name.length) {
                    writefln("\tget name %s optional %s", name, optional);
                    enum member_name=this.tupleof[i].stringof;
                    //  enum code=format("%s=doc[name].get!UnqualT;", member_name);
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    alias UnqualT=Unqual!BaseT;
                    pragma(msg, MemberT, ": ", BaseT, ": ", UnqualT);
                    static if (optional) {
                        if (!doc.hasMember(name)) {
                            continue ForeachTuple;
                        }
                    }
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
                        const x=doc[name].get!EnumBaseT;
                        static if (EnumContinuousSequency!BaseT) {
                            check((x >= BaseT.min) && (x <= BaseT.max),
                                message("The value %s is out side the range for %s enum type", x, BaseT.stringof));
                        }
                        else {
                        EnumCase:
                            switch (x) {
                                static foreach(E; EnumMembers!BaseT) {
                                case E:
                                    break EnumCase;
                                }
                            default:
                                check(0, format("The value %s does not fit into the %s enum type", x, BaseT.stringof));
                            }
                        }
                        writefln("EnumBaseT=%s BaseT=%s", EnumBaseT.stringof, BaseT.stringof);
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
    import tagion.hibon.HiBONException : check;
    immutable data=assumeUnique(cast(ubyte[])file.read(filename));
    const doc=Document(data);
    check(doc.isInorder, "HiBON Document format failed");
    return doc;
}

unittest {
    import std.stdio;
    import std.format;
    import std.exception : assertThrown, assertNotThrown;
    import std.traits : OriginalType, staticMap;
    import std.meta : AliasSeq;
    import tagion.hibon.HiBONJSON;
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
            // writefln("docS=\n%s", docS.toJSON(true).toPrettyString);
            // pragma(msg, "type docS=", typeof(docS));
            const s_check=Simpel(docS);
            // writefln("docS=\n%s", s_check.toDoc.toJSON(true).toPrettyString);
            // const s_check=Simpel(s);
            assert(s == s_check);
        }

        {
            const s=SimpelLabel(42, "other text");
            const docS=s.toDoc;
            writefln("keys=%s", docS.keys);
            assert(docS["$S"].get!int == 42);
            assert(docS["TEXT"].get!string == "other text");
            assert(docS[TYPENAME].get!string == SimpelLabel.type);
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
//            const check_s_no_filter_y=NotBothNoFilter(s_filter_y_doc);
//             writefln("s_filter_x=%s", s_filter_x);
// //            writefln("check_s_no_filter_y=%s", check_s_no_filter_y);
//             writefln("s_filter_y=%s", s_filter_y);
//             writefln("check_s_filter_y=%s", check_s_filter_y);
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
            writefln("docS=\n%s", s_filter_42_doc.toJSON(true).toPrettyString);
//            writefln("docS=\n%s", s_dont_filter_xy_doc.toJSON(true).toPrettyString);
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

    void EnumTest(T)() {  // Check enum
        enum Count : T {
            zero, one, two, three
        }
        alias OriginalCount = OriginalType!Count;

        static struct SimpleCount {
            Count count;
            mixin HiBONRecord;
        }

        SimpleCount s;
        s.count=Count.one;

        const s_doc=s.toDoc;
        writefln("s_doc=%s", s_doc.toJSON(true).toPrettyString);

        {
            const s_result = SimpleCount(s_doc);
            writefln("s_result=%s", s_result);
        }

        {
            auto h=new HiBON;
            h["count"]=OriginalCount(Count.max);
//            import std.traits : OriginalType;
            writefln("count %s %s", OriginalType!(typeof(Count.max)).stringof, OriginalType!(Count).stringof);
//            h["count"]=Count.max;


            const s_result = SimpleCount(Document(h.serialize));
            writefln("s_result=%s", s_result);
        }
    }

    static foreach(T; AliasSeq!(int, long, uint, ulong)) {
        EnumTest!T;
    }

    { // Invalid Enum
        enum NoCount {
            one=1, two, four=4
        }
        static struct SimpleNoCount {
            NoCount nocount;
            mixin HiBONRecord;
        }

        auto h=new HiBON;
        writeln("----- ----- -----");
        {
            enum nocount="nocount";
            {
//                auto h=new HiBON;
                h[nocount]=0;
                const doc=Document(h.serialize);
                assertThrown!HiBONRecordException(SimpleNoCount(doc));
            }
            {
                h.remove(nocount);
                // auto h=new HiBON;
                writeln("SET ONE");
                h[nocount]=NoCount.one;
                const doc=Document(h.serialize);
                writefln("h[nocount].type=%s", h[nocount].type);
                writefln("h[nocount].get!int=%s", h[nocount].get!int);
                writefln("doc=%s", doc.toJSON(true).toPrettyString);
                const x=SimpleNoCount(doc);
                assertNotThrown!Exception(SimpleNoCount(doc));
            }

            {
                h.remove(nocount);
//                auto h=new HiBON;
                h["nocount"]=3;
                const doc=Document(h.serialize);
                assertThrown!HiBONRecordException(SimpleNoCount(doc));
            }

            {
                h.remove(nocount);
//                auto h=new HiBON;
                h["nocount"]=NoCount.four;
                const doc=Document(h.serialize);
                assertNotThrown!Exception(SimpleNoCount(doc));
            }
        }
    }
    // {
    // enum Count {
    //     zero, one, two, three
    // }

    // pragma(msg, "EnumContinuousSequency!Count=", EnumContinuousSequency!Count);

    // enum NoCount {
    //     zero, one, three=3
    // }
    // pragma(msg, "EnumContinuousSequency!NoCount=", EnumContinuousSequency!NoCount);

    // enum OffsetCount {
    //     one=1, two, three
    // }
    // pragma(msg, "EnumContinuousSequency!OffsetCount=", EnumContinuousSequency!OffsetCount);

    // pragma(msg, "OffsetCount.min=", OffsetCount.min, " OffsetCount.max=%", OffsetCount.max);
    // }
}
