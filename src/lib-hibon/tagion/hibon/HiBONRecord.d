module tagion.hibon.HiBONRecord;
//import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual;
import tagion.hibon.HiBONBase : ValueT;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
/++
 Label use to set the HiBON member name
+/
struct Label {
    string name;
    bool optional;
//    string method;
}

template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;
    static if (hasUDA!(member, Label)) {
        enum GetLabel=getUDAs!(member, Label); //[0].name;
    }
    else {
        enum GetLabel=Label(basename!(member));
    }
}

mixin template HiBONRecord() {
    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual;
    import std.typecons : TypedefType;
    import tagion.hibon.HiBONException : check;
    import tagion.Message : message;
    import std.format;
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
                            else {
                                static assert(is(U == immutable), format("The array must be immutable not %s but ",
                                    BaseT.stringof, cast(immutable)U[].stringof));
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
        return hibon;
    }

    this(const Document doc) {
        import std.stdio;
        foreach(i, ref m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i])[0];
                    enum name=label.name;
                    static if (label.optional) {
                        if (!doc.hasElement(name)) {
                            break;
                        }
                    }
                }
                else {
                    enum name=basename!(this.tupleof[i]);
                }
                static if (name.length) {
                    enum member_name=this.tupleof[i].stringof;
                    enum code=format("%s=doc[name].get!BaseT;", member_name);
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    alias UnqualT=Unqual!BaseT;
                    static if (is(TypedefType!BaseT == struct)) {
                        pragma(msg, "@@@ ", TypedefType!BaseT);
                        const dub_doc = Document(doc[name].get!Document);
                        pragma(msg, code, " : ", BaseT.stringof);
                        enum doc_code=format("%s=MemberT(dub_doc);", member_name);
                        mixin(doc_code);
                        //m=MemberT(dub_doc);
                    }
                    else static if (is(BaseT == class)) {
                        const dub_doc = Document(doc[name].get!Document);
                        m=new MemberT(dub_doc);
                    }
                    else static if (is(BaseT == enum)) {
                        alias EnumBaseT=OriginalType!BaseT;
                        m=cast(BaseT)doc[name].get!EnumBaseT;
                    }
                    else {
                        static if (is(BaseT:U[], U)) {
                            static if (Document.Value.hasType!U) {
                                MemberT array;
                                writefln("Type=%s", doc[name].type);
                                auto doc_array=doc[name].get!Document;
                                writefln("doc_array.keys=%s %s", doc_array.keys, doc_array.isArray);
                                check(doc_array.isArray, message("Document array expected for %s member",  name));
                                foreach(e; doc_array[]) {
                                    array~=e.get!U;
                                }
                                m=array;
//                                static assert(0, format("Special handling of array %s", MemberT.stringof));
                            }
                            else {
                                static assert(is(U == immutable), format("The array must be immutable not %s but ",
                                    BaseT.stringof, cast(immutable)U[].stringof));
                                mixin(code);
                            }
                        }
                        else {
                            pragma(msg, code);
                            mixin(code);
                        }
                    }
                }
            }
        }
    }
}
