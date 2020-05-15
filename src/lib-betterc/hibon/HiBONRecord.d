module tagion.hibon.HiBONRecord;

extern(C):
@nogc:

import hibon.utils.Basic : basename;
import hibon.HiBONBase : ValueT;

import hibon.HiBON : HiBON;
import hibon.Document : Document;

/++
 Label use to set the HiBON member name
+/
struct Label {
    string name; /// Name of the HiBON member
    bool optional; /// This flag is set to true if this paramer is optional
}

/++
 Gets the Label for HiBON member
 Params:
 member = is the member alias
+/
template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;
    static if (hasUDA!(member, Label)) {
        enum GetLabel=getUDAs!(member, Label); //[0].name;
    }
    else {
        enum GetLabel=Label(basename!(member));
    }
}

/++
 HiBON Helper template to implement constructor and toHiBON member functions
 Params:
 TYPE = is used to set a HiBON record type ('$type')
 Examples:
 --------------------
 struct Test {
 @Label("$X") uint x; // The member in HiBON is "$X"
 string name;         // The member in HiBON is "name"
 @Label("num", true); // The member in HiBON is "num" and is optional
 @Label("") bool dummy; // This parameter is not included in the HiBON
 HiBONRecord("TEST");   // The "$type" is set to "TEST"
 }
 --------------------
+/

mixin template HiBONRecord(string TYPE="") {
    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual, hasMember;
    import std.typecons : TypedefType;
    import tagion.hibon.Bailout : check;
    import hibon.utils.Basic : basename;

    enum TYPENAME="$type";
    static if (TYPE.length) {
        string type() const pure nothrow {
            return TYPE;
        }
    }

    HiBON toHiBON() const {
        auto hibon= new HiBON;
        foreach(i, m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i])[0];
                    enum name=label.name;
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
                            hibon[name]=cast(BaseT)m;
                        }
                    }
                }
            }
        }
        static if (TYPE.length) {
            hibon[TYPENAME]=TYPE;
        }
        return hibon;
    }

    this(const Document doc) {
        static if (TYPE.length) {
            string _type=doc[TYPENAME].get!string;
            .check(_type == TYPE, format("Wrong %s type %s should be %s", TYPENAME, _type, type));
        }
    ForeachTuple:
        foreach(i, ref m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i])[0];
                    enum name=label.name;
                    enum optional=label.optional;
                    static if (label.optional) {
                        if (!doc.hasElement(name)) {
                            break;
                        }
                    }
                    static if (TYPE.length) {
                        static assert(TYPENAME != label.name,
                            format("Default %s is already definded to %s but is redefined for %s.%s",
                                TYPENAME, TYPE, typeof(this).stringof, basename!(this.tupleof[i])));
                    }
                }
                else {
                    enum name=basename!(this.tupleof[i]);
                    enum optional=false;
                }
                static if (name.length) {
                    enum member_name=this.tupleof[i].stringof;
                    enum code=format("%s=doc[name].get!BaseT;", member_name);
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    alias UnqualT=Unqual!BaseT;
                    static if (is(BaseT == struct)) {
                        auto dub_doc = doc[name].get!Document;
                        enum doc_code=format("%s=BaseT(dub_doc);", member_name);
                        mixin(doc_code);
                    }
                    else static if (is(BaseT == class)) {
                        const dub_doc = Document(doc[name].get!Document);
                        m=new BaseT(dub_doc);
                    }
                    else static if (is(BaseT == enum)) {
                        alias EnumBaseT=OriginalType!BaseT;
                        m=cast(BaseT)doc[name].get!EnumBaseT;
                    }
                    else {
                        static if (is(BaseT:U[], U)) {
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
                            else {
                                static assert(is(U == immutable), format("The array must be immutable not %s but is %s",
                                        BaseT.stringof, cast(immutable(U)[]).stringof));
                                mixin(code);
                            }
                        }
                        else {
                            mixin(code);
                        }
                    }
                }
            }
        }
    }
}
