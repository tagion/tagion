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
    string hibon_type;
    RegexT regex_name;
    RegexT regex_hibon_type;
    this(Name, HType, Types)(Name name, HType hibon_type = string.init, Types types = Type.init) pure
    
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
            this.hibon_type = hibon_type;
        }
        else {
            regex_hibon_type = hibon_type;
        }
        this.types ~= types;
    }

    bool match(const Document doc) const {
        bool result;
        if (!hibon_type.empty) {
            if (doc.getType != hibon_type) {
                return false;
            }
        }
        else if (!regex_hibon_type.isinit) {
            if (doc.getType.matchFirst(regex_hibon_type).empty) {
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
            if (types.empty) {
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
    @recordType("Sometype")
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

    const regex_doc = RegexDoc("text", 42, false);
    const doc = regex_doc.toDoc;
    { // Test hibon key name match
        assert(HiBONregex("name").match(doc));
        assert(HiBONregex(regex(`\d+`)).match(doc));
        assert(!HiBONregex("no match").match(doc));
        assert(!HiBONregex(regex(`no match`)).match(doc));

    }
    { // Test hibon record type match

    }
}
