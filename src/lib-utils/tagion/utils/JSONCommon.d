module tagion.utils.JSONCommon;

// import JSON=std.json;
// import std.format;
// import std.traits;
// import std.file;
// import std.getopt;
// import std.array : join;
// import std.string : strip;

import tagion.basic.Basic: basename, DataFormat;
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
    import tagion.basic.Basic: basename;
    import tagion.utils.JSONCommon : check;
    import JSON = std.json;
    import std.traits;
    import std.format;

    /++
     Returns:
     JSON of the struct
     +/
    JSON.JSONValue toJSON() const
    {
        JSON.JSONValue result;
        foreach (i, m; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            static if (is(type == struct)) {
                result[name] = m.toJSON;
            }
            else {
                static if (is(type : immutable(ubyte[]))) {
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
        else
        {
            return toJSON.toString;
        }
    }

    /++
     Intialize a struct from a JSON
     Params:
     json_value = JSON used
     +/
    void parse(ref JSON.JSONValue json_value) {
        foreach (i, ref m; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            static if (is(type == struct)) {
                m.parse(json_value[name]);
            }
            else static if (is(type == enum)) {
            TypeCase:
                switch (json_value[name].str) {
                    foreach (E; EnumMembers!type) {
                        enum E_text = strip(E.stringof, `"`);
                case E_text:
                        m = E;
                        break TypeCase;
                    }
                default:
                    string _EnumList() {
                        string[] enum_list;
                        static foreach (i, E; EnumMembers!type) {
                            enum_list ~= E.stringof;
                        }
                        if (enum_list.length is 1)
                        {
                            return enum_list[0];
                        }
                        else {
                            return format!("%s and %s")(enum_list[0 .. $ - 1].join(", "), enum_list[$ - 1]);
                        }
                    }

                    enum EnumList = _EnumList;
                    check(0, format("Illegal value of %s only %s supported not %s", name, EnumList, json_value[name]
                            .str));
                }
            }
            else static if (is(type == string)) {
                m = json_value[name].str;
            }
            else static if (isIntegral!type || isFloatingPoint!type) {
                static if (isIntegral!type) {
                    auto value = json_value[name].integer;
                }
                else {
                    auto value = json_value[name].floating;
                }
                check((value >= type.min) && (value <= type.max), format("Value %d out of range for type %s of %s", value, type
                        .stringof, m.stringof));
                m = cast(type) value;

            }
            else static if (is(type == bool)) {
                check((json_value[name].type == JSON.JSONType.true_) || (
                        json_value[name].type == JSON.JSONType.false_),
                        format("Type %s expected for %s but the json type is %s", type.stringof, m.stringof, json_value[name]
                        .type));
                m = json_value[name].type == JSON.JSONType.true_;
            }
            else
            {
                check(0, format("Unsupported type %s for %s member", type.stringof, m.stringof));
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
        else
        {
            save(config_file);
        }
    }

    void save(string config_file)
    {
        config_file.write(stringify);
    }
}
