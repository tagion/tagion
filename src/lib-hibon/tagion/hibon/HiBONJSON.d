module tagion.hibon.HiBONJSON;

//import std.stdio;

import std.json;
import std.conv : to;
import std.format;
import std.traits : EnumMembers, Unqual, ReturnType, ForeachType;
import std.range.primitives : isInputRange;

import tagion.hibon.BigNumber;
import tagion.hibon.HiBONBase : Type, isNative, isArray, isHiBONType;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.Message : message;
// import tagion.utils.JSONOutStream;
// import tagion.utils.JSONInStream : JSONType;

import tagion.TagionExceptions : Check;
import tagion.utils.Miscellaneous : toHex=toHexString, decode;

/**
 * Exception type used by tagion.hibon.HiBON module
 */
@safe
class HiBON2JSONException : HiBONException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

alias check=Check!HiBON2JSONException;

enum NotSupported = "none";

protected Type[string] generateLabelMap(const(string[Type]) typemap) {
    Type[string] result;
    foreach(e, label; typemap) {
        if (label != NotSupported) {
            result[label]=e;
        }
    }
    return result;
}

enum typeMap=[
    Type.NONE     : NotSupported,
    Type.FLOAT32  : "f32",
    Type.FLOAT64  : "f64",
    Type.STRING   : "text",
    Type.DOCUMENT : "{}",
    Type.BOOLEAN  : "bool",
    Type.UTC      : "utc",
    Type.INT32    : "i32",
    Type.INT64    : "i64",
    Type.UINT32   : "u32",
    Type.UINT64   : "u64",
    Type.BIGINT   : "int",

    Type.DEFINED_NATIVE : NotSupported,
    Type.BINARY         : "bin",
    Type.INT32_ARRAY    : "i32[]",
    Type.INT64_ARRAY    : "i64[]",
    Type.FLOAT64_ARRAY  : "f64[]",
    Type.FLOAT32_ARRAY  : "f32[]",
    Type.BOOLEAN_ARRAY  : "bool[]",
    Type.UINT32_ARRAY   : "u32[]",
    Type.UINT64_ARRAY   : "u64[]",
    Type.DEFINED_ARRAY         : NotSupported,
    Type.NATIVE_DOCUMENT       : NotSupported ,
    Type.NATIVE_HIBON_ARRAY    : NotSupported,
    Type.NATIVE_DOCUMENT_ARRAY : NotSupported ,
    Type.NATIVE_STRING_ARRAY   : NotSupported
    ];

unittest {
    static foreach(E; EnumMembers!Type) {
        assert(E in typeMap, format("TypeMap %s is not defined", E));
    }
}
//    generateTypeMap;
enum labelMap=generateLabelMap(typeMap);


enum {
    TYPE=0,
    VALUE=1,
}

@safe
JSONValue toJSON(Document doc, bool hashsafe=true) {
    if (hashsafe) {
        return toJSONT!true(doc);
    }
    else {
        return toJSONT!false(doc);
    }
}

@safe
struct toJSONT(bool HASHSAFE) {
    @trusted
    static JSONValue opCall(const Document doc) {
        JSONValue result;
        immutable isarray=doc.isArray;
        if (isarray) {
            // Array needs to be initialized
            result.array=null;
        }
//        writefln("HASHSAFE=%s",HASHSAFE);
        foreach(e; doc[]) {
            with(Type) {
            CaseType:
                switch(e.type) {
                    static foreach(E; EnumMembers!Type) {
                        static if (isHiBONType(E)) {
                        case E:
                            static if (E is Type.DOCUMENT) {
                                const sub_doc=e.by!E;
                                auto doc_element=toJSONT(sub_doc);
                                if ( isarray ) {
                                    if (doc_element.type is JSONType.array) {
                                        result.array~=JSONValue(doc_element);
                                    }
                                    else {
                                        result.array~=doc_element;
                                    }
                                }
                                else {
                                    result[e.key]=doc_element;
                                }
                            }
                            else {
                                auto doc_element=new JSONValue[2];
                                doc_element[TYPE]=JSONValue(typeMap[E]);
                                static if (E is UTC) {
                                    assert(0, format("%s is not implemented yet", E));
                                }
                                else static if (isArray(E) && (E !is BINARY)) {
                                    alias T=Document.Value.TypeT!E;
                                    alias U=ForeachType!T;
                                    alias JSType=JSONTypeT!U;
                                    scope JSType[] array;
                                    foreach(a; e.by!E) {
                                        array~=toJSONType(a);
                                    }
                                    doc_element[VALUE]=array;
                                }
                                else static if(E is BIGINT) {
                                    doc_element[VALUE]=e.by!(E).toDecimalString;
                                }
                                else {
                                    doc_element[VALUE]=toJSONType(e.by!E);
                                }

                                if ( isarray ) {
                                    result.array~=JSONValue(doc_element);
                                }
                                else {
                                    result[e.key]=doc_element;
                                }
                            }
                            break CaseType;
                        }
                    }
                default:
                    .check(0, message("HiBON type %s notsupported and can not be converted to JSON", e.type));
                }
            }
        }
        return result;
    }


    template JSONTypeT(T) {
        alias UnqualT=Unqual!T;
        static if (is(UnqualT == bool)) {
            alias JSONTypeT=bool;
        }
        else static if (is(UnqualT == string)) {
            alias JSONTypeT=string;
        }
        else static if(is(UnqualT == ulong) || is(UnqualT == long)) {
            alias JSONTypeT=string;
        }
        else static if(is(UnqualT == uint) || is(UnqualT == int)) {
            alias JSONTypeT=UnqualT;
        }
        else static if(is(T : immutable(ubyte)[])) {
            alias JSONTypeT=string;
        }
        else static if(is(T : const BigNumber)) {
            alias JSONTypeT=string;
        }
        else static if(is(UnqualT  : double)) {
            static if (HASHSAFE) {
                alias JSONTypeT=string;
            }
            else {
                alias JSONTypeT=double;
            }
        }
        else {
            static assert(0, format("Unsuported type %s", T.stringof));
        }
    }

    static auto toJSONType(T)(T x) {
        alias UnqualT=Unqual!T;
        static if (is(UnqualT == bool)) {
            return x;
        }
        else static if(is(UnqualT == string)) {
            return x;
        }
        else static if(is(UnqualT == ulong) || is(UnqualT == long)) {
            return format("%d", x);
        }
        else static if(is(UnqualT == uint) || is(UnqualT == int)) {
            return x;
        }
        else static if(is(T : immutable(ubyte)[])) {
            return format("0x%s", x.toHex);
        }
        else static if(is(UnqualT  : double)) {
            static if (HASHSAFE) {
                return format("%a", x);
            }
            else {
                return cast(double)x;
            }
        }
        else static if(is(T : const BigNumber)) {
            return x.to!string;
        }
        else {
            static assert(0, message("Unsuported type %s", T.stringof));
        }
    }

}

HiBON toHiBON(scope const JSONValue json) {
    static const(T) get(T)(scope JSONValue jvalue) {
        alias UnqualT=Unqual!T;
        static if (is(UnqualT==bool)) {
            return jvalue.boolean;
        }
        else static if(is(UnqualT==uint)) {
            return jvalue.integer.to!uint;
        }
        else static if(is(UnqualT==int)) {
            return jvalue.integer.to!int;
        }
        else static if(is(UnqualT==long) || is(UnqualT==ulong)) {
            return jvalue.str.to!UnqualT;
        }
        else static if(is(UnqualT==string)) {
            return jvalue.str;
        }
        else static if(is(T==immutable(ubyte)[])) {
            return decode(jvalue.str);
        }
        else static if(is(T:const(double))) {
            if (jvalue.type is JSONType.float_) {
                return jvalue.floating.to!UnqualT;
            }
            else {
                return jvalue.str.to!UnqualT;
            }
        }
        else static if(is(T:U[],U)) {
            scope array=new U[jvalue.array.length];
            foreach(i, ref a; jvalue) {
                array[i]=a.get!U;
            }
            return array.idup;
        }
        else static if (is(T : const BigNumber)) {
            return BigNumber(jvalue.str);
        }
        else {
            static assert(0, format("Type %s is not supported", T.stringof));
        }
        assert(0);
    }

    //static HiBON Obj(scope JSONValue json);


    static HiBON Obj(scope JSONValue json) {
    static bool set(ref HiBON sub_result, string key, scope JSONValue jvalue) {
        immutable label=jvalue.array[TYPE].str;
        .check((label in labelMap) !is null, "HiBON type name '%s' is not valid", label);
        immutable type=labelMap[label];

        with(Type) {
            final switch(type) {
                static foreach(E; EnumMembers!Type) {
                case E:
                    static if (isHiBONType(E)) {
                        alias T=HiBON.Value.TypeT!E;
                        scope value=jvalue.array[VALUE];

                        static if(E is DOCUMENT) {
                            return false;
                        }
                        else {
                            static if(E is UTC) {
                                assert(0, format("Type %s is supported yet", E));
                            }
                            else static if(E is BINARY) {
                                import std.uni : toLower;
                                scope str=value.str;
                                enum HEX_PREFIX="0x";
                                .check(str[0..HEX_PREFIX.length].toLower == HEX_PREFIX,
                                    message("Hex prefix %s expected for type %s", HEX_PREFIX, E));
                                sub_result[key]=decode(str[HEX_PREFIX.length..$]);
                            }
                            else static if (isArray(E)) {
                                .check(value.type is JSONType.array, message("JSON array expected for %s for member %s", E, key));
                                alias U=Unqual!(ForeachType!T);
                                scope array=new U[value.array.length];
                                foreach(size_t i, ref e; value) {
                                    array[i]=get!U(e);
                                }
                                sub_result[key]=array.idup;

                            }
                            // else static if (E is BIGINT) {

                            //     assert(0, format("%s is not supported yet", E));
                            //}
                            else {
                                sub_result[key]=get!T(value);
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
        HiBON result=new HiBON;
        // static foreach(E; EnumMembers!JSONType) {
        //     writefln("case %s:\nbreak;", E);
        // }
        foreach(string key, ref jvalue;json) {
            with(JSONType) {
                final switch(jvalue.type) {
                case null_:
                    .check(0, "HiBON does not support null");
                    break;
                case string:
                    result[key]=jvalue.str;
                    break;
                case integer:
                    result[key]=jvalue.integer;
                    break;
                case uinteger:
                    result[key]=jvalue.uinteger;
                    break;
                case float_:
                    result[key]=jvalue.floating;
                    break;
                case array:
                    if (!set(result, key, jvalue)) {
                        result[key]=Obj(jvalue);
                    }
                    break;
                case object:
                    result[key]=Obj(jvalue);
                    break;
                case true_:
                    result[key]=true;
                    break;
                case false_:
                    result[key]=false;
                    break;
                }
            }
        }
        return result;
    }
    return Obj(json);
}

unittest {
    import tagion.hibon.HiBON : HiBON;
    import std.typecons : Tuple;
    alias Tabel = Tuple!(
        float,  Type.FLOAT32.stringof,
        double, Type.FLOAT64.stringof,
        bool,   Type.BOOLEAN.stringof,
        int,    Type.INT32.stringof,
        long,   Type.INT64.stringof,
        uint,   Type.UINT32.stringof,
        ulong,  Type.UINT64.stringof,
        BigNumber, Type.BIGINT.stringof,

//                utc_t,  Type.UTC.stringof
        );

    Tabel test_tabel;
    test_tabel.FLOAT32 = 1.23;
    test_tabel.FLOAT64 = 1.23e200;
    test_tabel.INT32   = -42;
    test_tabel.INT64   = -0x0123_3456_789A_BCDF;
    test_tabel.UINT32   = 42;
    test_tabel.UINT64   = 0x0123_3456_789A_BCDF;
    test_tabel.BOOLEAN  = true;
    test_tabel.BIGINT   = BigNumber("-1234_5678_9123_1234_5678_9123_1234_5678_9123");


    alias TabelArray = Tuple!(
        immutable(ubyte)[],  Type.BINARY.stringof,
        immutable(float)[],  Type.FLOAT32_ARRAY.stringof,
        immutable(double)[], Type.FLOAT64_ARRAY.stringof,
        immutable(int)[],    Type.INT32_ARRAY.stringof,
        immutable(long)[],   Type.INT64_ARRAY.stringof,
        immutable(uint)[],   Type.UINT32_ARRAY.stringof,
        immutable(ulong)[],  Type.UINT64_ARRAY.stringof,
        immutable(bool)[],   Type.BOOLEAN_ARRAY.stringof,
        string,              Type.STRING.stringof

        );
    TabelArray test_tabel_array;
    test_tabel_array.BINARY        = [1, 2, 3];
    test_tabel_array.FLOAT32_ARRAY = [-1.23, 3, 20e30];
    test_tabel_array.FLOAT64_ARRAY = [10.3e200, -1e-201];
    test_tabel_array.INT32_ARRAY   = [-11, -22, 33, 44];
    test_tabel_array.INT64_ARRAY   = [0x17, 0xffff_aaaa, -1, 42];
    test_tabel_array.UINT32_ARRAY  = [11, 22, 33, 44];
    test_tabel_array.UINT64_ARRAY  = [0x17, 0xffff_aaaa, 1, 42];
    test_tabel_array.BOOLEAN_ARRAY = [true, false];
    test_tabel_array.STRING        = "Text";

    auto hibon=new HiBON;
    {
        foreach(i, t; test_tabel) {
            enum name=test_tabel.fieldNames[i];
            hibon[name]=t;
        }
        auto sub_hibon = new HiBON;
        hibon[sub_hibon.stringof]=sub_hibon;
        foreach(i, t; test_tabel_array) {
            enum name=test_tabel_array.fieldNames[i];
            sub_hibon[name]=t;
        }
    }

    //
    // Checks
    // HiBON -> Document -> JSON -> HiBON -> Document
    //
    const doc=Document(hibon.serialize);

    auto json=doc.toJSON(true);
    // import std.stdio;
    // writefln("%s", json.toPrettyString);
    string str=json.toString;
    auto parse=str.parseJSON;
    auto h=parse.toHiBON;

    const parse_doc=Document(h.serialize);
//    writefln("After %s", parse_doc.toJSON(true).toPrettyString);

    assert(doc == parse_doc);
    assert(doc.toJSON(true).toString == parse_doc.toJSON(true).toString);
}
