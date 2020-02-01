module tagion.hibon.HiBONRecord;

struct Label {
    string name;
}

mixin template HiBONRecord() {
    HiBON toHiBON() {
        auto hibon=new HiBON;
        foreach(i, m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                static if (hasUDA!(this.tupleof[i], Label)) {
                    enum name=getUDAs!(this.tupleof[i], Label)[0].name;
                }
                else {
                    enum name=basename!(this.tupleof[i]);
                }
                static if (name.length) {
                    pragma(msg, name);
                    alias MemberT=typeof(m);
                    static if (__traits(compiles, m.toHiBON)) {
                        hibon[name]=m.toHiBON;
                    }
                    else static if (is(MemberT == enum)) {
                        hibon[name]=cast(OriginalType!MemberT)m;
                    }
                    else static if (is(MemberT == class) || is(MemberT == struct)) {
                        static assert(0, format(`A sub class/struct %s must have a toHiBON or must be ingnored will @Label("") UDA tag`, name));
                    }
                    else {
                        hibon[name]=cast(TypedefType!MemberT)m;
                    }
                }
            }
        }
        return hibon;
    }

    this(const Document doc) {
        foreach(i, ref m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                static if (hasUDA!(this.tupleof[i], Label)) {
                    enum name=getUDAs!(this.tupleof[i], Label)[0].name;
                }
                else {
                    enum name=basename!(this.tupleof[i]);
                }
                static if (name.length) {
                    enum member_name=this.tupleof[i].stringof;
                    enum code=format("%s=doc[name].get!Type;", member_name);
                    alias Type=typeof(m);
                    alias UnqualT=Unqual!Type;
                    static if (is(Type == struct)) {
                        const dub_doc = Document(doc[name].get!Document);
                        m=Type(dub_doc);
                    }
                    else static if (is(Type == class)) {
                        const dub_doc = Document(doc[name].get!Document);
                        m=new Type(dub_doc);
                    }
                    else static if (is(Type == enum)) {
                        alias BaseT=OriginalType!UnqualT;
                        m=cast(BaseT)(doc[name].get!Type);
                    }
                    else {
                        static if (is(Type:U[], U)) {
                            static assert(is(U == immutable), format("The array must be immutable not %s but ",
                                    Type.stringof, cast(immutable)U[].stringof));
                            pragma(msg, Type, " : ", U, " : ", this.tupleof[i].stringof);

                        }
                        pragma(msg, code);
                        mixin(code);
                    }
                }
            }
        }
    }
}
