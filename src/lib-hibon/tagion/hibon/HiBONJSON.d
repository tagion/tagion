module tagion.hibon.HiBONJSON;

@safe:
import std.conv : to;
import std.format;
import std.json;
import std.range.primitives : isInputRange;
import std.traits : EnumMembers, ForeachType, ReturnType, Unqual;
import std.base64;

//import std.stdio;

import tagion.basic.Message : message;
import tagion.hibon.BigNumber;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONBase;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.hibon.HiBONtoText;

// import tagion.utils.JSONOutStream;
// import tagion.utils.JSONInStream : JSONType;

import tagion.basic.tagionexceptions : Check;
import tagion.utils.StdTime;

/**
 * Exception type used by tagion.hibon.HiBON module
 */
class HiBON2JSONException : HiBONException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

import std.datetime.timezone;
import core.lifetime;

private class DefinitelyNotLocalTime : TimeZone {
    LocalTime lt;

    this() immutable {
        lt = LocalTime();
        super(lt.name, lt.stdName, lt.dstName);
    }

    override bool hasDST() const nothrow @property @safe => lt.hasDST;
    override bool dstInEffect(long stdTime) const nothrow scope @safe => lt.dstInEffect(stdTime);
    override long utcToTZ(long stdTime) const nothrow scope @safe => lt.utcToTZ(stdTime);
    override long tzToUTC(long adjTime) const nothrow scope @safe => lt.tzToUTC(adjTime);
}

private immutable DefinitelyNotLocalTime def_not_local_time;

shared static this() {
    def_not_local_time = new immutable(DefinitelyNotLocalTime);
}

static unittest {
    assert(def_not_local_time !is LocalTime());
}

private alias check = Check!HiBON2JSONException;

enum NotSupported = "none";

protected Type[string] generateLabelMap(const(string[Type]) typemap) {
    Type[string] result;
    foreach (e, label; typemap) {
        if (label != NotSupported) {
            result[label] = e;
        }
    }
    return result;
}

enum typeMap = [
    Type.NONE: NotSupported,
    Type.VER: NotSupported,
    Type.FLOAT32: "f32",
    Type.FLOAT64: "f64",
    Type.STRING: "$",
    Type.BINARY: "*",
    Type.DOCUMENT: "{}",
    Type.BOOLEAN: "bool",
    Type.TIME: "time",
    Type.INT32: "i32",
    Type.INT64: "i64",
    Type.UINT32: "u32",
    Type.UINT64: "u64",
    Type.BIGINT: "big",

    Type.DEFINED_NATIVE: NotSupported,

    Type.DEFINED_ARRAY: NotSupported,
    Type.NATIVE_DOCUMENT: NotSupported,
    Type.NATIVE_HIBON_ARRAY: NotSupported,
    Type.NATIVE_DOCUMENT_ARRAY: NotSupported,
    Type.NATIVE_STRING_ARRAY: NotSupported
];

static unittest {
    static foreach (E; EnumMembers!Type) {
        assert(E in typeMap, format("TypeMap %s is not defined", E));
    }
}
//    generateTypeMap;
enum labelMap = generateLabelMap(typeMap);

enum {
    TYPE = 0,
    VALUE = 1,
}

JSONValue toJSON(Document doc) {
    return toJSONT!true(doc);
}

JSONValue toJSON(T)(T value) if (isHiBONRecord!T) {
    return toJSONT!true(value.toDoc);
}

string toPretty(T)(T value) {
    static if (is(T : const(HiBON))) {
        const doc = Document(value);
        return doc.toJSON.toPrettyString;
    }
    else {
        return value.toJSON.toPrettyString;
    }
}

mixin template JSONString() {
    import std.conv : to;
    import std.format;

    alias ThisT = typeof(this);

    void toString(scope void delegate(scope const(char)[]) @safe sink, const FormatSpec!char fmt) const {
        import tagion.basic.Types;
        import tagion.hibon.Document;
        import tagion.hibon.HiBON;
        import tagion.hibon.HiBONJSON;
        import tagion.hibon.HiBONRecord;

        static if (isHiBONRecord!ThisT) {
            const doc = this.toDoc;
        }
        else static if (is(ThisT : const(Document))) {
            const doc = this;
        }
        else static if (is(ThisT : const(HiBON))) {
            const doc = Document(this);
        }
        else {
            static assert(0, format("type %s in %s is not supported for JSONString", ThisT.stringof, moduleName!ThisT));
        }
        switch (fmt.spec) {
        case 'j':
            // Normal stringefied JSON
            sink(doc.toJSON.toString);
            break;
        case 'J':
            // Normal stringefied JSON
            sink(doc.toJSON.toPrettyString);
            break;
        case 's':
            sink(doc.serialize.to!string);
            break;
        case '@':
            sink(doc.serialize.encodeBase64);
            break;
        case 'x':
            sink(format("%(%02x%)", doc.serialize));
            break;
        case 'X':
            sink(format("%(%02x%)", doc.serialize));
            break;
        default:
            throw new HiBON2JSONException("Unknown format specifier: %" ~ fmt.spec);
        }
    }
}

struct toJSONT(bool HASHSAFE) {
    @trusted static JSONValue opCall(const Document doc) {
        JSONValue result;
        immutable isarray = doc.isArray && !doc.empty;
        if (isarray) {
            result.array = null;
            result.array.length = doc.length;
        }
        else {
            result.object = null;
        }
        foreach (e; doc[]) {
            with (Type) {
            CaseType:
                switch (e.type) {
                    static foreach (E; EnumMembers!Type) {
                        static if (isHiBONBaseType(E)) {
                case E:
                            static if (E is DOCUMENT) {
                                const sub_doc = e.by!E;
                                auto doc_element = toJSONT(sub_doc);
                                if (isarray) {
                                    result.array[e.index] = JSONValue(doc_element);
                                }
                                else {
                                    result[e.key] = doc_element;
                                }
                            }
                            else static if ((E is BOOLEAN) || (E is STRING)) {
                                if (isarray) {
                                    result.array[e.index] = JSONValue(e.by!E);
                                }
                                else {
                                    result[e.key] = JSONValue(e.by!E);
                                }
                            }
                            else {
                                auto doc_element = new JSONValue[2];
                                doc_element[TYPE] = JSONValue(typeMap[E]);
                                if (isarray) {
                                    result.array[e.index] = toJSONType(e);
                                }
                                else {
                                    result[e.key] = toJSONType(e);
                                }
                            }
                            break CaseType;
                        }
                    }
                default:

                    

                        .check(0, message("HiBON type %s not supported and can not be converted to JSON",
                                e.type));
                }
            }
        }
        return result;
    }

    static JSONValue[] toJSONType(Document.Element e) {
        auto doc_element = new JSONValue[2];
        doc_element[TYPE] = JSONValue(typeMap[e.type]);
        with (Type) {
        TypeCase:
            switch (e.type) {
                static foreach (E; EnumMembers!Type) {
            case E:
                    static if (E is BOOLEAN) {
                        doc_element[VALUE] = e.by!E;
                    }
                    else static if (E is INT32 || E is UINT32) {

                        doc_element[VALUE] = e.by!(E);
                    }
                    else static if (E is INT64 || E is UINT64) {
                        doc_element[VALUE] = format("0x%x", e.by!(E));
                    }
                    else static if (E is BIGINT) {
                        doc_element[VALUE] = encodeBase64(e.by!(E).serialize);
                    }
                    else static if (E is BINARY) {
                        doc_element[VALUE] = encodeBase64(e.by!(E));
                    }
                    else static if (E is FLOAT32 || E is FLOAT64) {
                        static if (HASHSAFE) {
                            doc_element[VALUE] = format("%a", e.by!E);
                        }
                        else {
                            doc_element[VALUE] = e.by!E;
                        }
                    }
                    else static if (E is TIME) {
                        import std.datetime;

                        SysTime sys_time = SysTime(cast(long) e.by!E);
                        sys_time.timezone = def_not_local_time;

                        doc_element[VALUE] = sys_time.toISOExtString;
                    }
                    else {
                        goto default;
                    }
                    break TypeCase;
                }
            default:
                throw new HiBONException(format("Unsuported HiBON type %s", e.type));
            }
        }
        return doc_element;
    }
}

HiBON toHiBON(scope const JSONValue json) {
    static const(T) get(T)(scope JSONValue jvalue) {
        alias UnqualT = Unqual!T;
        static if (is(UnqualT == bool)) {
            return jvalue.boolean;
        }
        else static if (is(UnqualT == uint)) {
            long x = jvalue.integer;

            

            .check((x > 0) && (x <= uint.max), format("%s not a u32", jvalue));
            return cast(uint) x;
        }
        else static if (is(UnqualT == int)) {
            return jvalue.integer.to!int;
        }
        else static if (is(UnqualT == long) || is(UnqualT == ulong)) {
            const text = jvalue.str;
            ulong result;
            if (isHexPrefix(text)) {
                result = text[hex_prefix.length .. $].to!ulong(16);
            }
            else {
                result = text.to!UnqualT;
            }
            static if (is(UnqualT == long)) {
                return cast(long) result;
            }
            else {
                return result;
            }
        }
        else static if (is(UnqualT == string)) {
            return jvalue.str;
        }
        else static if (is(T == immutable(ubyte)[])) {
            return decode(jvalue.str);
        }
        else static if (is(T : const(double))) {
            if (jvalue.type is JSONType.float_) {
                return jvalue.floating.to!UnqualT;
            }
            else {
                return jvalue.str.to!UnqualT;
            }
        }
        else static if (is(T : U[], U)) {
            scope array = new U[jvalue.array.length];
            foreach (i, ref a; jvalue) {
                array[i] = a.get!U;
            }
            return array.idup;
        }
        else static if (is(T : const BigNumber)) {
            const text = jvalue.str;
            if (isBase64Prefix(text) || isHexPrefix(text)) {
                const data = decode(text);
                return BigNumber(data);
            }
            return BigNumber(jvalue.str);
        }
        else static if (is(T : const sdt_t)) {
            import std.datetime;
            import std.algorithm;

            const text_time = get!string(jvalue);
            check(isoHasTZ(text_time), "The timestamp should contain a timezone at the end like '+01:00' or 'Z'");
            check(text_time.endsWith("Z") || text_time.endsWith("00"), "BUG: cannot convert timestamps with none whole hour timestamps eg '01:05'");
            const sys_time = SysTime.fromISOExtString(text_time);
            return sdt_t(sys_time.stdTime);
        }
        else {
            static assert(0, format("Type %s is not supported", T.stringof));
        }
        assert(0);
    }

    static HiBON JSON(Key)(scope JSONValue json) {
        static bool set(ref HiBON sub_result, Key key, scope JSONValue jvalue) {
            if (jvalue.type is JSONType.string) {
                sub_result[key] = jvalue.str;
                return true;
            }
            else if ((jvalue.type is JSONType.true_) || (jvalue.type is JSONType.false_)) {
                sub_result[key] = jvalue.boolean;
                return true;
            }
            if ((jvalue.array.length != 2) || (jvalue.array[TYPE].type !is JSONType.STRING) || !(jvalue.array[TYPE].str in labelMap)) {
                return false;
            }
            immutable label = jvalue.array[TYPE].str;
            immutable type = labelMap[label];

            with (Type) {
                final switch (type) {
                    static foreach (E; EnumMembers!Type) {
                case E:
                        static if (isHiBONBaseType(E)) {
                            alias T = HiBON.Value.TypeT!E;
                            scope value = jvalue.array[VALUE];

                            static if (E is DOCUMENT) {
                                return false;
                            }
                            else {
                                static if (E is BINARY) {
                                    import std.uni : toLower;

                                    sub_result[key] = decode(value.str).idup;
                                }
                                else {
                                    sub_result[key] = get!T(value);
                                }
                                return true;
                            }
                        }
                        else {
                            assert(0, format("Unsupported type %s for member %s", E, key));
                        }
                    }
                }
            }

            assert(0);
        }

        HiBON result = new HiBON;
        foreach (Key key, ref jvalue; json) {
            with (JSONType) {
                final switch (jvalue.type) {
                case null_:

                    

                        .check(0, "HiBON does not support null");
                    break;
                case string:
                    result[key] = jvalue.str;
                    break;
                case integer:
                    result[key] = jvalue.integer;
                    break;
                case uinteger:
                    result[key] = jvalue.uinteger;
                    break;
                case float_:
                    result[key] = jvalue.floating;
                    break;
                case array:
                    if (!set(result, key, jvalue)) {
                        result[key] = Obj(jvalue);
                    }
                    break;
                case object:
                    result[key] = Obj(jvalue);
                    break;
                case true_:
                    result[key] = true;
                    break;
                case false_:
                    result[key] = false;
                    break;
                }
            }
        }
        return result;
    }

    @trusted static HiBON Obj(scope JSONValue json) {
        if (json.type is JSONType.ARRAY) {
            return JSON!size_t(json);
        }
        else if (json.type is JSONType.OBJECT) {
            return JSON!string(json);
        }

        

        .check(0, format("JSON_TYPE must be of %s or %s not %s",
                JSONType.OBJECT, JSONType.ARRAY, json.type));
        assert(0);
    }

    return Obj(json);
}

HiBON toHiBON(const(char[]) json_text) {
    const json = json_text.parseJSON;
    return json.toHiBON;
}

Document toDoc(scope const JSONValue json) {
    return Document(json.toHiBON);
}

Document toDoc(const(char[]) json_text) {
    const json = parseJSON(json_text);
    return json.toDoc;
}

// An extra check for iso time strings to see if they have a timezone
private bool isoHasTZ(string iso_ext) pure nothrow {
    import std.algorithm;
    import std.regex;

    // Match a iso tz string at the end of string eg: blala+01:03
    alias match_tz = ctRegex!`.*([+-]\d{2}:\d{2})$`;

    try {
        return iso_ext.endsWith("Z") || matchFirst(iso_ext, match_tz);
    }
    catch (Exception e) {
        return false;
    }
}

unittest {
    assert(isoHasTZ("Z"));
    assert(isoHasTZ("+01:02"));
    assert(isoHasTZ("-01:02"));
    assert(isoHasTZ("2024-02-07T09:06:16.6852971+01:00"));
    assert(isoHasTZ("2024-02-07T09:06:16.6852971-01:00"));
    assert(isoHasTZ("+01:02Z"));

    assert(!isoHasTZ("z"));
    assert(!isoHasTZ("ZaZZa"));
    assert(!isoHasTZ("+a1:02"));
    assert(!isoHasTZ("+005:02"));
    assert(!isoHasTZ("+01:02a"));
    assert(!isoHasTZ("2024-02-07T09:06-01:00:16.6852971"));
}

unittest {
    //    import std.stdio;
    import std.typecons : Tuple;
    import tagion.hibon.HiBON : HiBON;

    alias Tabel = Tuple!(
            float, Type.FLOAT32.stringof,
            double, Type.FLOAT64.stringof,
            bool, Type.BOOLEAN.stringof,
            int, Type.INT32.stringof,
            long, Type.INT64.stringof,
            uint, Type.UINT32.stringof,
            ulong, Type.UINT64.stringof,
            BigNumber, Type.BIGINT.stringof,
            sdt_t, Type.TIME.stringof);

    Tabel test_tabel;
    test_tabel.FLOAT32 = 1.23;
    test_tabel.FLOAT64 = 1.23e200;
    test_tabel.INT32 = -42;
    test_tabel.INT64 = -0x0123_3456_789A_BCDF;
    test_tabel.UINT32 = 42;
    test_tabel.UINT64 = 0x0123_3456_789A_BCDF;
    test_tabel.BOOLEAN = true;
    test_tabel.BIGINT = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");

    pragma(msg, "fixme, hibonjson ISO time does not work with un whole timezones");
    test_tabel.TIME = sdt_t(638402115766852971); // Whole TZ +01:00
    /* test_tabel.TIME = sdt_t(1001); */ // Un whole TZ +00:53

    alias TabelArray = Tuple!(
            immutable(ubyte)[], Type.BINARY.stringof,
            string, Type.STRING.stringof,
    );
    TabelArray test_tabel_array;
    test_tabel_array.BINARY = [1, 2, 3];
    test_tabel_array.STRING = "Text";

    { // Empty Document
        const doc = Document();
        assert(doc.toJSON.toString == "{}");
    }

    { // Test sample 1 HiBON Objects
        auto hibon = new HiBON;
        {
            foreach (i, t; test_tabel) {
                enum name = test_tabel.fieldNames[i];
                hibon[name] = t;
            }
            auto sub_hibon = new HiBON;
            hibon[sub_hibon.stringof] = sub_hibon;
            foreach (i, t; test_tabel_array) {
                enum name = test_tabel_array.fieldNames[i];
                sub_hibon[name] = t;
            }
        }

        //
        // Checks
        // HiBON -> Document -> JSON -> HiBON -> Document
        //
        const doc = Document(hibon);

        pragma(msg, "fixme(cbr): For some unknown reason toString (mixin JSONString)",
                " is not @safe for Document and HiBON");

        assert(doc.toJSON.toPrettyString == doc.toPretty);
        assert(doc.toJSON.toPrettyString == hibon.toPretty);
    }

    { // Test sample 2 HiBON Array and Object
        auto hibon = new HiBON;
        {
            foreach (i, t; test_tabel) {
                hibon[i] = t;
            }
            auto sub_hibon = new HiBON;
            hibon[sub_hibon.stringof] = sub_hibon;
            foreach (i, t; test_tabel_array) {
                sub_hibon[i] = t;
            }
        }

        //
        // Checks
        // HiBON -> Document -> JSON -> HiBON -> Document
        //
        const doc = Document(hibon);

        auto json = doc.toJSON;

        string str = json.toString;
        auto parse = str.parseJSON;
        auto h = parse.toHiBON;

        const parse_doc = Document(h.serialize);

        assert(doc == parse_doc);
        assert(doc.toJSON.toString == parse_doc.toJSON.toString);
    }

    { // Test sample 3 HiBON Array and Object
        auto hibon = new HiBON;
        {
            foreach (i, t; test_tabel) {
                hibon[i] = t;
            }
            auto sub_hibon = new HiBON;
            // Sub hibon is added to the last index of the hibon
            // Which result keep hibon as an array
            hibon[hibon.length] = sub_hibon;
            foreach (i, t; test_tabel_array) {
                sub_hibon[i] = t;
            }
        }

        //
        // Checks
        // HiBON -> Document -> JSON -> HiBON -> Document
        //
        const doc = Document(hibon);

        auto json = doc.toJSON;

        string str = json.toString;
        auto parse = str.parseJSON;
        auto h = parse.toHiBON;

        const parse_doc = Document(h.serialize);

        assert(doc == parse_doc);
        assert(doc.toJSON.toString == parse_doc.toJSON.toString);
    }

    { // Check that ISOExt string has a timezone
        import tagion.utils.StdTime;

        auto hibon = new HiBON();

        hibon["t"] = currentTime;

        auto hjson = Document(hibon).toJSON();
        assert(hjson["t"][1].get!string.isoHasTZ);
    }
}

unittest {
    import std.stdio;
    import tagion.hibon.HiBONRecord;

    static struct S {
        int[] a;
        mixin HiBONRecord!(q{
            this(int[] a) {
                this.a=a;
            }
         });
    }

    { /// Checks that an array of two elements is converted correctly
        const s = S([20, 34]);
        immutable text = s.toPretty;
        //const json = text.parseJSON;
        const h = text.toHiBON;
        const doc = Document(h);
        const result_s = S(doc);
        assert(result_s == s);
    }

    { /// Checks 
        const s = S([17, -20, 42]);
        immutable text = s.toJSON;
        const result_s = S(text.toDoc);
        assert(result_s == s);

    }

}
