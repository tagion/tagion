module tagion.utils.envexpand;

import std.typecons;
import std.algorithm;
import std.range;

enum bracket_pairs = [
        ["$(", ")"],
        ["${", "}"],
        ["$", ""],

    ];

@safe
string envExpand(string text, string[string] env, void delegate(string msg) error = null) pure {
    alias BracketState = Tuple!(string[], "bracket", ptrdiff_t, "index");
    static long envName(string str, string end_sym, const size_t index) pure {
        import std.uni;

        long innerEnv(string _str) {
            if (end_sym.length) {
                return _str.countUntil(end_sym);
            }
            if ((_str.length > 0) && !_str[0].isAlpha) {
                return -1;
            }
            const x = (_str ~ '!').countUntil!(c => !c.isAlphaNum);
            return x;
        }

        const result = innerEnv(str[index .. $]);
        return (result < 0) ? result : result + index;
    }

    string innerExpand(string str) {
        string result = str;

        auto begin = bracket_pairs
            .map!(bracket => BracketState(bracket, str.countUntil(bracket[0])))
            .filter!(state => state.index >= 0)
            .take(1);
        if (!begin.empty) {
            const state = begin.front;
            //            const size_t start
            const env_start_index = state.index + state.bracket[0].length;

            string env_name;
            string env_value;
            const env_end_index = envName(str, state.bracket[1], env_start_index);
            size_t next_index = env_start_index;
            if (env_end_index > 0) {
                env_name = str[env_start_index .. env_end_index];
                env_name = innerExpand(env_name);
                env_value = env.get(env_name, null);

                next_index = env_end_index + state.bracket[1].length;
            }
            return str[0 .. state.index] ~
                env_value ~
                innerExpand(str[next_index .. $]);
        }
        return result;

    }

    return innerExpand(text);
}

@safe
unittest {
    import std.stdio;

    writefln("%s", "text".envExpand(null));

    // Simple text without env expansion
    assert("text".envExpand(null) == "text");
    writefln("%s", "text$(NAME)".envExpand(null));
    // Expansion with undefined env
    assert("text$(NAME)".envExpand(null) == "text");
    writefln("%s", "text$(NAME)".envExpand(["NAME": "hugo"]));
    // Expansion where the env is defined
    assert("text$(NAME)".envExpand(["NAME": "hugo"]) == "texthugo");
    writefln("%s", "text${NAME}end".envExpand(["NAME": "hugo"]));
    // Full expansion 
    assert("text${NAME}end".envExpand(["NAME": "hugo"]) == "texthugoend");
    writefln("%s", "text$NAME".envExpand(["NAME": "hugo"]));
    // Environment without brackets
    assert("text$NAME".envExpand(["NAME": "hugo"]) == "texthugo");
    writefln("%s", "text$NAMEend".envExpand(["NAME": "hugo"]));
    // Undefined env without brackets expansion
    assert("text$NAMEend".envExpand(["NAME": "hugo"]) == "text");
    writefln("%s", "text$(OF${NAME})".envExpand(["NAME": "hugo"]));
    // Expansion of undefined environment of environment
    assert("text$(OF${NAME})".envExpand(["NAME": "hugo"]) == "text");

    writefln("%s", "text$(OF${NAME})".envExpand(["NAME": "hugo", "OFhugo": "_extra_"]));
    // Expansion of defined environment of environment
    assert("text$(OF${NAME})".envExpand(["NAME": "hugo", "OFhugo": "_extra_"]) == "text_extra_");

}
