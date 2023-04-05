module tagion.utils.JSONCommon;

import tagion.basic.TagionExceptions;
import std.meta : AliasSeq;
import std.traits : hasMember;

/++
 +/
@safe
class OptionException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

enum isJSONCommon(T) = is(T == struct) && hasMember!(T, "toJSON");

/++
 mixin for implememts a JSON interface for a struct
 +/
mixin template JSONCommon() {
    import tagion.basic.TagionExceptions : Check;
    import tagion.utils.JSONCommon : OptionException;

    alias check = Check!OptionException;
    import tagion.basic.basic : basename, isOneOf, assumeTrusted;
    import JSON = std.json;
    import std.traits;
    import std.format;
    import std.conv : to;
    import std.meta : AliasSeq;
    import std.range : ElementType;

    //    import std.traits : isArray;
    alias ArrayElementTypes = AliasSeq!(bool, string);

    enum isSupportedArray(T) = isArray!T && isSupported!(ElementType!T);
    enum isSupported(T) = isOneOf!(T, ArrayElementTypes) || isNumeric!T || isSupportedArray!T || isJSONCommon!T;

    /++
     Returns:
     JSON of the struct
     +/
    JSON.JSONValue toJSON() const @safe {
        JSON.JSONValue result;
        foreach (i, m; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            static if (is(type == struct)) {
                result[name] = m.toJSON;
            }
            else static if (isArray!type && is(ElementType!type == struct)) {
                JSON.JSONValue[] array;
                foreach (ref m_element; m) {
                    array ~= m_element.toJSON;
                }
                result[name] = array; // ~= m_element.toJSON;

            }
            else {
                static if (is(type == enum)) {
                    result[name] = m.to!string;
                }
                else static if (is(type : immutable(ubyte[]))) {
                    result[name] = m.toHexString;
                }
            else {
                    result[name] = m;
                }
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
     Intialize a struct from a JSON
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
            else {
                check(0, format("Unsupported type %s for '%s' member", T.stringof, _name));
            }
            return true;
        }

        ParseLoop: foreach (i, ref member; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(member);
            //            static if (!is(type == struct) || !is(type == class)) {
            static assert(is(type == struct) || is(type == enum) || isSupported!type,
                    format("Unsupported type %s for '%s' member", type.stringof, name));

            if (!set(member, json_value[name], name)) {
                continue ParseLoop;
            }

        }
    }

}

mixin template JSONConfig() {
    import JSON = std.json;
    import std.file;

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

    void save(string config_file) @safe {
        config_file.write(stringify);
    }
}

version (unittest) {
    import tagion.basic.Types : FileExtension;
    import basic = tagion.basic.basic;
    import std.exception : assertThrown;
    import std.json : JSONException;

    const(basic.FileNames) fileId(T)(string prefix = null) @safe {
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
        mixin JSONCommon;
        mixin JSONConfig;
    }

    OptS opt;
    { // Simple JSONCommon check
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
        mixin JSONCommon;
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

    { // Check for bad JSONCommon file
        OptS opt_s;
        //immutable bad_filename = fileId!OptMain("bad").fullpath;
        assertThrown!JSONException(opt_s.load(main_filename));
    }

}

unittest { // JSONCommon with array types
    //    import std.stdio;
    static struct OptArray(T) {
        T[] list;
        mixin JSONCommon;
        mixin JSONConfig;
    }

    //alias StdType=AliasSeq!(bool, int, string, Color);

    { // Check JSONCommon with array of booleans
        alias OptA = OptArray!bool;
        OptA opt;
        opt.list = [true, false, false, true, false];
        immutable filename = fileId!OptA.fullpath;

        opt.save(filename);

        OptA opt_loaded;
        opt_loaded.load(filename);

        assert(opt_loaded == opt);
    }

    { // Check JSONCommon with array of string
        alias OptA = OptArray!string;
        OptA opt;
        opt.list = ["Hugo", "Borge", "Brian", "Johnny", "Sven Bendt"];
        immutable filename = fileId!OptA.fullpath;

        opt.save(filename);

        OptA opt_loaded;
        opt_loaded.load(filename);

        assert(opt_loaded == opt);
    }

    { // Check JSONCommon with array of integers
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
            mixin JSONCommon;
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
