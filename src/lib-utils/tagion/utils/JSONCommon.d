module tagion.utils.JSONCommon;

import tagion.basic.TagionExceptions;

/++
 +/
@safe
class OptionException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

alias check = Check!OptionException;

/++
 mixin for implememts a JSON interface for a struct
 +/
mixin template JSONCommon() {
    import tagion.basic.Basic : basename, isOneOf;
    import tagion.utils.JSONCommon : check;
    import JSON = std.json;
    import std.traits;
    import std.format;
    import std.conv : to;
    import std.meta : AliasSeq;
    import std.range : ElementType;
    import std.traits : isArray;

    alias ArrayElementTypes = AliasSeq!(bool);

    enum isSupportedArray(T) = isArray!T && isOneOf!(ElementType!T, ArrayElementTypes);

    /++
     Returns:
     JSON of the struct
     +/
    JSON.JSONValue toJSON() const {
        JSON.JSONValue result;
        foreach (i, m; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            static if (is(type == struct)) {
                result[name] = m.toJSON;
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
    string stringify(bool pretty = true)() const {
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
    void parse(ref JSON.JSONValue json_value) {
        static void set_array(T)(ref T m, ref JSON.JSONValue[] json_array, string name) if (isSupportedArray!T) {
                //check(0, format("Array %s ", m));
                foreach(_json_value; json_array) {
                    pragma(msg, "T ", T);
                    ElementType!T m_element;
                    set(m_element, _json_value, name);
                    m~=m_element;
                }
            }
            static bool set(T)(ref T m, ref JSON.JSONValue _json_value, string name) {
//                alias ElementOfMember = Element
                // check(json_value[name].array is JSON.JSONType.array, format("Illegal type %s for %s must be %s",
                //         [EnumMembers!type],
                //         name,
                //         JSON.JSONT.array));


                static if (is(T == struct)) {
                    m.parse(_json_value[name]);
                }
                else static if (is(T == enum)) {
                    if (_json_value[name].type is JSON.JSONType.string) {
                        switch (_json_value[name].str) {
                            foreach (E; EnumMembers!T) {
                            case E.to!string:
                                m = E;
                                return false;
//                            continue ParseLoop;
                            }
                        default:
                            check(0, format("Illegal value of %s only %s supported not %s",
                                    name, [EnumMembers!T],
                                    _json_value[name].str));
                        }
                    }
                    else static if (isIntegral!(BuiltinTypeOf!T)) {
                        if (_json_value[name].type is JSON.JSONType.integer) {
                            const value = _json_value[name].integer;
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
                                name,
                                [EnumMembers!T],
                                _json_value[name].uinteger));
                    }
                    check(0, format("Illegal value of %s", name));
                }
                else static if (is(T == string)) {
                    m = _json_value[name].str;
                }
                else static if (isIntegral!T || isFloatingPoint!T) {
                    static if (isIntegral!T) {
                        auto value = _json_value[name].integer;
                        check((value >= T.min) && (value <= T.max), format("Value %d out of range for type %s of %s", value, T
                                .stringof, m.stringof));
                    }
                    else {
                        auto value = _json_value[name].floating;
                    }
                    m = cast(T) value;

                }
                else static if (is(T == bool)) {
                    check((_json_value[name].type == JSON.JSONType.true_) || (
                            _json_value[name].type == JSON.JSONType.false_),
                        format("Type %s expected for %s but the json type is %s", T.stringof, m.stringof, _json_value[name]
                            .type));
                    m = _json_value[name].type == JSON.JSONType.true_;
                }
                else static if (isSupportedArray!T) {
                    //isArray!type && isOneOf!(ElementType!type, ArrayElementTypes)) {

//                import std.stdio;
                    pragma(msg, "isArray ", isArray!T);
                    pragma(msg, "isOneOf ", isOneOf!(ElementType!T, ArrayElementTypes));
                    pragma(msg, "ArrayElementTypes ", ArrayElementTypes);
//                parse_array(json_value[name]
                    check(_json_value[name].type is JSON.JSONType.array,
                        format("Type of member '%s' must be an %s", name, JSON.JSONType.array));
                    set_array(m, _json_value[name].array, name);



                }
                else {
                    static assert(0, format("Unsupported type %s for '%s' member", T.stringof, name));
                }
                return true;
            }
    ParseLoop: foreach (i, ref member; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(member);
            if (!set(member, json_value, name)) {
                continue ParseLoop;
            }

        }
    }

}

mixin template JSONConfig() {
    import JSON = std.json;
    import std.file;

    void parseJSON(string json_text) {
        auto json = JSON.parseJSON(json_text);
        parse(json);
    }

    void load(string config_file) {
        if (config_file.exists) {
            auto json_text = readText(config_file);
            parseJSON(json_text);
        }
        else {
            save(config_file);
        }
    }

    void save(string config_file) {
        config_file.write(stringify);
    }
}

version(unittest) {
    import tagion.basic.Types : FileExtension;
    import Basic = tagion.basic.Basic;
    import std.exception : assertThrown;
    import std.json : JSONException;
    const(Basic.FileNames) fileId(T)(string prefix = null) @safe {
        return Basic.fileId!T(FileExtension.json, prefix);
    }

    private enum Color {
        red,
        green,
        blue,
    }

}

unittest {
    import std.stdio;


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
        opt._bool=true;
        opt._string="text";
        // opt._double=4.2;
        opt._int = -42;
        opt._uint = 42;
        opt.color = Color.blue;

        writeln(opt.stringify);
        immutable filename = fileId!OptS.fullpath;
        // immutable filename = Basic.fileId!OptS(FileExtension.json, null).fullpath;
//    (FileExtension..fullpath;
        opt.save(filename);
//FileExtension
        OptS opt_loaded;
        opt_loaded.load(filename);
        writeln(opt_loaded.stringify);
//    filename.fwrite(

        writefln("opt       =%s", opt);
        writefln("opt_loaded=%s", opt_loaded);
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
        opt_main.sub_opt=opt;
        opt_main.main_x = 117;
        opt_main.save(main_filename);
//FileExtension
        OptMain opt_loaded;
        opt_loaded.load(main_filename);
        writeln(opt_loaded.stringify);
//    filename.fwrite(

        writefln("opt_main       =%s", opt_main);
        writefln("opt_loaded=%s", opt_loaded);
        assert(opt_main == opt_loaded);
    }

    { // Check for bad JSONCommon file
        OptS opt_s;
        //immutable bad_filename = fileId!OptMain("bad").fullpath;
        assertThrown!JSONException(opt_s.load(main_filename));
    }

}

unittest { // JSONCommon with array types
    import std.stdio;
    static struct OptArray(T) {
        T[] list;
        mixin JSONCommon;
        mixin JSONConfig;
    }

    //alias StdType=AliasSeq!(bool, int, string, Color);

    { // Check JSONCommon with array of booleans
        alias OptA=OptArray!bool;
        OptA opt;
        opt.list=[true, false, false, true, false];
        immutable filename = fileId!OptA.fullpath;

        writefln(opt.stringify);
        opt.save(filename);

        OptA opt_loaded;
        opt_loaded.load(filename);
    }
}
