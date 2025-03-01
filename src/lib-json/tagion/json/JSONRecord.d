/// JSON Interface for structs
module tagion.json.JSONRecord;

import std.meta : AliasSeq;
import std.traits : hasMember;
import tagion.errors.tagionexceptions;
public import tagion.hibon.HiBONRecord : optional, exclude, GetLabel;

@safe:
/++
 +/
class OptionException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

enum isJSONRecord(T) = is(T == struct) && hasMember!(T, "toJSON");

/++
 mixin for implements a JSON interface for a struct
 +/
mixin template JSONRecord() {
    import tagion.errors.tagionexceptions : Check;
    import tagion.json.JSONRecord : OptionException;
    import tagion.hibon.HiBONRecord : optional, exclude, GetLabel;

    alias check = Check!OptionException;
    import std.conv : to;
    import std.format;
    import JSON = std.json;
    import std.meta : AliasSeq;
    import std.range : ElementType;
    import std.traits;
    import tagion.basic.basic : assumeTrusted, basename, isOneOf;

    //    import std.traits : isArray;
    alias ArrayElementTypes = AliasSeq!(bool, string, double, int);

    enum isSupportedArray(T) = isArray!T && isSupported!(ElementType!T);
    enum isSupportedAssociativeArray(T) = isAssociativeArray!T && is(KeyType!T == string) && isSupported!(ForeachType!T);
    enum isSupported(T) = isOneOf!(T, ArrayElementTypes) || isNumeric!T ||
        isSupportedArray!T || isJSONRecord!T ||
        isSupportedAssociativeArray!T;

    /++
     Returns:
     JSON of the struct
     +/
    JSON.JSONValue toJSON() const @safe {
        JSON.JSONValue result;
        auto get(type, T)(T val) {

            static if (is(type == enum)) {
                return val.to!string;
            }
            else static if (is(type : immutable(ubyte[]))) {
                return val.toHexString;
            }
            else static if (is(type == struct)) {
                return val.toJSON;
            }
            else {
                return val;
            }
        }

        ValueLoop: foreach (i, m; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            enum exclude_flag = hasUDA!(this.tupleof[i], exclude);
            static if (exclude_flag) {
                continue ValueLoop;
            }
            static if (is(type == struct)) {
                result[name] = m.toJSON;
            }
            else static if (isArray!type && isSupported!(ForeachType!type)) {
                alias ElemType = ForeachType!type;
                JSON.JSONValue[] array;
                foreach (ref m_element; m) {
                    JSON.JSONValue val = get!ElemType(m_element);
                    array ~= val;
                }
                result[name] = array; // ~= m_element.toJSON;
            }
            else static if (isSupportedAssociativeArray!type) {
                JSON.JSONValue obj;
                alias ElemType = ForeachType!type;
                foreach (key, m_element; m) {
                    obj[key] = get!ElemType(m_element);
                }
                result[name] = obj;
            }
            else {
                result[name] = get!(type)(m);
            }
        }
        return result;
    }

    /++
     Stringify the struct
     Params:
     pretty = if true the return string is prettified else the string returned is compact
     +/
    string stringify(bool pretty = true)() const @safe {
        static if (pretty) {
            return toJSON.toPrettyString;
        }
        else {
            return toJSON.toString;
        }
    }

    /++
     Initialize a struct from a JSON
     Params:
     json_value = JSON used
     +/
    void parse(ref JSON.JSONValue json_value) @safe {
        static void set_array(T)(ref T m, ref JSON.JSONValue[] json_array, string name) @safe if (isSupportedArray!T) {
            foreach (_json_value; json_array) {
                ElementType!T m_element;
                set(m_element, _json_value, name);
                m ~= m_element;
            }
        }

        static void set_hashmap(T)(ref T m, ref JSON.JSONValue[string] json_array, string name) @safe
                if (isSupportedAssociativeArray!T) {
            alias ElemType = ForeachType!T;
            foreach (key, json_value; json_array) {
                ElemType val;
                set(val, json_value, name);
                m[key] = val;
            }

        }

        static bool set(T)(ref T m, ref JSON.JSONValue _json_value, string _name) @safe {

            static if (is(T == struct)) {
                m.parse(_json_value);
            }
            else static if (is(T == enum)) {
                if (_json_value.type is JSON.JSONType.string) {
                    switch (_json_value.str) {
                        foreach (E; EnumMembers!T) {
                    case E.to!string:
                            m = E;
                            return false;
                            //                            continue ParseLoop;
                        }
                    default:
                        check(0, format("Illegal value of %s only %s supported not %s",
                                _name, [EnumMembers!T],
                                _json_value.str));
                    }
                }
                else static if (isIntegral!(BuiltinTypeOf!T)) {
                    if (_json_value.type is JSON.JSONType.integer) {
                        const value = _json_value.integer;
                        switch (value) {
                            foreach (E; EnumMembers!T) {
                        case E:
                                m = E;
                                return false;
                                //continue ParseLoop;
                            }
                        default:
                            // Fail;

                        }
                    }
                    check(0, format("Illegal value of %s only %s supported not %s",
                            _name,
                            [EnumMembers!T],
                            _json_value.uinteger));
                }
                check(0, format("Illegal value of %s", _name));
            }
            else static if (is(T == string)) {
                m = _json_value.str;
            }
            else static if (isIntegral!T || isFloatingPoint!T) {
                static if (isIntegral!T) {
                    auto value = _json_value.integer;
                    check((value >= T.min) && (value <= T.max), format("Value %d out of range for type %s of %s", value, T
                            .stringof, m.stringof));
                }
                else {
                    auto value = _json_value.floating;
                }
                m = cast(T) value;

            }
            else static if (is(T == bool)) {
                check((_json_value.type == JSON.JSONType.true_) || (
                        _json_value.type == JSON.JSONType.false_),
                        format("Type %s expected for %s but the json type is %s", T.stringof, m.stringof, _json_value
                        .type));
                m = _json_value.type == JSON.JSONType.true_;
            }
            else static if (isSupportedArray!T) {
                check(_json_value.type is JSON.JSONType.array,
                        format("Type of member '%s' must be an %s", _name, JSON.JSONType.array));
                (() @trusted => set_array(m, _json_value.array, _name))();

            }
            else static if (isSupportedAssociativeArray!T) {
                check(_json_value.type is JSON.JSONType.object,
                        format("Type of member '%s' must be an %s", _name, JSON.JSONType.object));
                (() @trusted => set_hashmap(m, _json_value.object, _name))();

            }
            else {
                check(0, format("Unsupported type %s for '%s' member", T.stringof, _name));
            }
            return true;
        }

        ParseLoop: foreach (i, ref member; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(member);
            static assert(is(type == struct) || is(type == enum) || isSupported!type,
                    format("Unsupported type %s for '%s' member", type.stringof, name));

            enum exclude_flag = hasUDA!(this.tupleof[i], exclude);
            static if (exclude_flag) {
                continue ParseLoop;
            }
            enum optional_flag = hasUDA!(this.tupleof[i], optional);
            static if (optional_flag) {
                if (!(name in json_value)) {
                    continue ParseLoop;
                }
            }

            // Ignore if a member is missing
            JSON.JSONValue name_value;
            try {
                name_value = json_value[name];
            }
            catch(JSON.JSONException e) {
                continue ParseLoop;
            }
            
            if (!set(member, name_value, name)) {
                continue ParseLoop;
            }

        }
    }

}

static T load(T)(string config_file) if (__traits(hasMember, T, "load")) {
    T result;
    result.load(config_file);
    return result;
}

import std.conv;
import std.json : JSONType, JSONValue;

JSONValue toJSONType(string str, JSONType type) pure {
    with (JSONType) final switch (type) {
    case float_:
        return JSONValue(str.to!float);
    case integer:
        return JSONValue(str.to!int);
    case uinteger:
        return JSONValue(str.to!uint);
    case null_:
        return JSONValue(null);
    case object, array, string: //best guess
        return JSONValue(str);
    case false_, true_:
        return JSONValue(str.to!bool);
    }
}

mixin template JSONConfig() {
    import std.file;
    import JSON = std.json;

    void parseJSON(string json_text) @safe {
        auto json = JSON.parseJSON(json_text);
        parse(json);
    }

    void load(string config_file) @safe {
        if (config_file.exists) {
            auto json_text = readText(config_file);
            parseJSON(json_text);
        }
        else {
            save(config_file);
        }
    }

    void save(const string config_file) @safe const {
        config_file.write(stringify);
    }
}

version (unittest) {
    import std.exception : assertThrown;
    import std.json : JSONException;
    import tagion.basic.Types : FileExtension;
    import basic = tagion.basic.basic;

    const(basic.FileNames) fileId(T)(string prefix = null) {
        return basic.fileId!T(FileExtension.json, prefix);
    }

    private enum Color {
        red,
        green,
        blue,
    }

}

unittest {
    static struct OptS {
        bool _bool;
        string _string;
        //        double _double;
        int _int;
        uint _uint;
        Color color;
        mixin JSONRecord;
        mixin JSONConfig;
    }

    OptS opt;
    { // Simple JSONRecord check
        opt._bool = true;
        opt._string = "text";
        // opt._double=4.2;
        opt._int = -42;
        opt._uint = 42;
        opt.color = Color.blue;

        immutable filename = fileId!OptS.fullpath;
        opt.save(filename);
        OptS opt_loaded;
        opt_loaded.load(filename);
        assert(opt == opt_loaded);
    }
    static struct OptMain {
        OptS sub_opt;
        int main_x;
        mixin JSONRecord;
        mixin JSONConfig;
    }

    immutable main_filename = fileId!OptMain.fullpath;

    { // Common check with sub a sub-structure
        OptMain opt_main;
        opt_main.sub_opt = opt;
        opt_main.main_x = 117;
        opt_main.save(main_filename);
        //FileExtension
        OptMain opt_loaded;
        opt_loaded.load(main_filename);
        assert(opt_main == opt_loaded);
    }

    version(THIS_DOES_NOT_THROW)
    { // Check for bad JSONRecord file
        OptS opt_s;
        //immutable bad_filename = fileId!OptMain("bad").fullpath;
        assertThrown!JSONException(opt_s.load(main_filename));
    }

}

unittest { // JSONRecord with array types
    //    import std.stdio;
    static struct OptArray(T) {
        T[] list;
        mixin JSONRecord;
        mixin JSONConfig;
    }

    //alias StdType=AliasSeq!(bool, int, string, Color);

    { // Check JSONRecord with array of booleans
        alias OptA = OptArray!bool;
        OptA opt;
        opt.list = [true, false, false, true, false];
        immutable filename = fileId!OptA.fullpath;

        opt.save(filename);

        OptA opt_loaded;
        opt_loaded.load(filename);

        assert(opt_loaded == opt);
    }

    { // Check JSONRecord with array of string
        alias OptA = OptArray!string;
        OptA opt;
        opt.list = ["Hugo", "Borge", "Brian", "Johnny", "Sven Bendt"];
        immutable filename = fileId!OptA.fullpath;

        opt.save(filename);

        OptA opt_loaded;
        opt_loaded.load(filename);

        assert(opt_loaded == opt);
    }

    { // Check JSONRecord with array of integers
        alias OptA = OptArray!int;
        OptA opt;
        opt.list = [42, -16, 117];
        immutable filename = fileId!OptA.fullpath;

        opt.save(filename);

        OptA opt_loaded;
        opt_loaded.load(filename);

        assert(opt_loaded == opt);
    }

    {
        static struct OptSub {
            string text;
            mixin JSONRecord;
        }

        alias OptA = OptArray!OptSub;
        OptA opt;
        opt.list = [OptSub("Hugo"), OptSub("Borge"), OptSub("Brian")];
        immutable filename = fileId!OptA.fullpath;

        opt.save(filename);

        OptA opt_loaded;
        opt_loaded.load(filename);

        assert(opt_loaded == opt);
    }
}

unittest { // Check of support for associative array
    static struct S {
        string[string] names;
        mixin JSONRecord;
    }

    S s;
    s.names["Hugo"] = "big";
    s.names["Borge"] = "small";

    auto json = s.toJSON;

    S s_result;
    s_result.parse(json);
    assert("Hugo" in s_result.names);
    assert("Borge" in s_result.names);
    assert(s_result.names["Hugo"] == "big");
    assert(s_result.names["Borge"] == "small");

}

unittest { /// Check @optional 
    import std.stdio;
    import std.exception : assertNotThrown, assertThrown;

    static struct S {
        int x;
        @optional string name;
        mixin JSONRecord;
        mixin JSONConfig;
    }

    { // name is @optional
        S s;
        s.name = "old name";
        // name has a @optional so it should not throw
        assertNotThrown(s.parseJSON(`{ "x" : 42 }`));
        assert(s.x == 42);
        assert(s.name == "old name", "name should not change");
    version(THIS_DOES_NOT_THROW)
        assertThrown(s.parseJSON(`{ "name" : "new name" }`));
    }
}

unittest { /// Check @exclude 
    import std.exception : assertNotThrown, assertThrown;

    static struct S {
        @exclude int x;
        string name;
        mixin JSONRecord;
        mixin JSONConfig;
    }

    string json_text;
    { // x is @exclude
        S s1;
        s1.x = 42;
        s1.name = "old name";
        json_text = s1.stringify;
    }
    { // convert to s2 from json text
        S s2;
        s2.x = 17;
        s2.name = "other name";
        assertNotThrown(s2.parseJSON(json_text));
        assert(s2.name == "old name");
        assert(s2.x == 17, "Should not change because of @exclude");
    }
}
