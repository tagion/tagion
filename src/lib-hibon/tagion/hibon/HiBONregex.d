module tagion.hinon.HiBONregex;

@safe:
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONRecord;
import std.regex;
import tagion.hibon.Document;
import std.range;
import std.algorithm;
import tagion.basic.basic;

struct HiBONregex {
    alias RegexT = Regex!char;
    uint[] types;
    string name;
    string record_type;
    RegexT regex_name;
    RegexT regex_record_type;
    this(Name, HType, Types)(Name name, HType record_type, Types types) pure

    

            if ((is(Name == string) || is(Name == RegexT)) &&
                (is(HType == string) || is(HType == RegexT)) &&
                (is(Types
                : const(Type))) || is(Types : const(Type[]))) {
        static if (is(Name == string)) {
            this.name = name;
        }
        else {
            regex_name = name;
        }
        static if (is(HType == string)) {
            this.record_type = record_type;
        }
        else {
            regex_record_type = record_type;
        }
        import std.algorithm : filter;
        import std.array;

        Type[] _types;
        _types ~= types;
        this.types = _types
            .filter!(type => type !is Type.NONE)
            .map!(type => cast(uint) type)
            .array;
    }

    this(Name)(Name name) pure {
        this(name, string.init, Type.init);
    }

    this(Name, HType)(Name name, HType record_type) pure {
        this(name, record_type, Type.init);
    }

    bool match(const Document doc) const {
        bool result;
        if (!record_type.empty) {
            if (record_type == "!") {
                return doc.getType.isinit;
            }
            if (doc.getType != record_type) {
                return false;
            }
        }
        else if (!regex_record_type.isinit) {
            if (doc.getType.matchFirst(regex_record_type).empty) {
                return false;
            }
        }
        bool canMatch(const Document.Element elm) {
            if (!name.empty) {
                if (elm.key != name) {
                    return false;
                }
            }
            else if (!regex_name.isinit) {
                if (elm.key.matchFirst(regex_name).empty) {
                    return false;
                }
            }
            if (!types.empty) {
                if (!types.canFind(elm.type)) {
                    return false;
                }
            }
            return true;
        }

        return doc[].any!(elm => canMatch(elm));
    }

    bool match(T)(T rec) if (isHiBONRecord!T) {
        return match(rec.toDoc);
    }
}

///
unittest {
    enum record_type_name = "Some_type";
    @recordType(record_type_name)
    static struct RegexDoc {
        string name;
        int x;
        @label("12") bool flag;
        mixin HiBONRecord!(q{
            this(string name, int x, bool flag) {
                this.name=name;
                this.x=x;
                this.flag=flag;
            }
        });
    }

    static struct NoRecordType {
        int x;
        mixin HiBONRecord;
    }

    const no_record_type_doc = NoRecordType.init.toDoc;
    const regex_doc = RegexDoc("text", 42, false);
    const doc = regex_doc.toDoc;
    { // Test hibon key name match
        assert(HiBONregex("name").match(doc));
        assert(HiBONregex(regex(`\d+`)).match(doc));
        assert(!HiBONregex("no match").match(doc));
        assert(!HiBONregex(regex(`no match`)).match(doc));

    }
    { // Test hibon record type match
        assert(HiBONregex(string.init, record_type_name).match(doc));
        assert(!HiBONregex(string.init, "Not found").match(doc));
        assert(HiBONregex(string.init, regex(`_\w+`)).match(doc));
        assert(!HiBONregex(string.init, regex(`_\d+`)).match(doc));
        assert(!HiBONregex(string.init, "!").match(doc));
        assert(HiBONregex(string.init, "!").match(no_record_type_doc));
    }
    { // Test hibon record type match
        assert(HiBONregex(string.init, string.init, Type.STRING).match(doc));
        assert(!HiBONregex(string.init, string.init, Type.BINARY).match(doc));
        assert(HiBONregex(string.init, string.init, [Type.BINARY, Type.STRING]).match(doc));
        assert(!HiBONregex(string.init, string.init, [Type.BINARY, Type.BIGINT]).match(doc));
    }
}
