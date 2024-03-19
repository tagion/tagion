module tagion.utils.envexpand;

import std.algorithm;
import std.range;
import std.typecons;

enum ignore_env_start = "!";
enum bracket_pairs = [
        ["$$", "$", ignore_env_start], // "!" ignored as environment start
        ["$(", ")"],
        ["${", "}"],
        ["$", ""],

    ];

@safe
string envExpand(string text, string[string] env, void delegate(string msg) error = null) pure {
    alias BracketState = Tuple!(string[], "bracket", ptrdiff_t, "index");
    static long envName(string str, string end_sym) pure {
        import std.uni;

        if (end_sym.length) {
            return str.countUntil(end_sym);
        }
        if ((str.length > 0) && !str[0].isAlpha) {
            return -1;
        }
        return (str ~ '!').countUntil!(c => !c.isAlphaNum);
    }

    string innerExpand(string str) {
        auto begin = bracket_pairs
            .map!(bracket => BracketState(bracket, str.countUntil(bracket[0])))
            .filter!(state => state.index >= 0);
        //  .take(1);
        if (!begin.empty) {
            const state = begin.front;
            if (state.bracket.length > 2) {
                const next_index = state.index + state.bracket[0].length;
                return str[0 .. state.index] ~ state.bracket[1] ~ innerExpand(str[next_index .. $]);
            }
            const env_start_index = state.index + state.bracket[0].length;
            auto end_str = innerExpand(str[env_start_index .. $]);
            const env_end_index = envName(end_str, state.bracket[1]);
            string env_value;
            if (env_end_index > 0) {
                const env_name = end_str[0 .. env_end_index];
                end_str = end_str[env_end_index + state.bracket[1].length .. $];
                env_value = env.get(env_name, null);
            }
            return str[0 .. state.index] ~
                env_value ~
                innerExpand(end_str);
        }
        return str;

    }

    return innerExpand(text);
}

@safe
unittest {
    // Simple text without env expansion
    assert("text".envExpand(null) == "text");
    // Expansion with undefined env
    assert("text$(NAME)".envExpand(null) == "text");
    // Expansion where the env is defined
    assert("text$(NAME)".envExpand(["NAME": "hugo"]) == "texthugo");
    // Full expansion 
    assert("text${NAME}end".envExpand(["NAME": "hugo"]) == "texthugoend");
    // Environment without brackets
    assert("text$NAME".envExpand(["NAME": "hugo"]) == "texthugo");
    // Undefined env without brackets expansion
    assert("text$NAMEEend".envExpand(["NAME": "hugo"]) == "text");
    // Expansion of undefined environment of environment
    assert("text$(OF${NAME})".envExpand(["NAME": "hugo"]) == "text");
    // Expansion of defined environment of environment
    assert("text$(OF${NAME})".envExpand(["NAME": "hugo", "OFhugo": "_extra_"]) == "text_extra_");
    // Expansion of defined environment of environment
    assert("text$(OF$(NAME)_end)".envExpand([
        "NAME": "hugo",
        "OFhugo": "_extra_",
        "OFhugo_end": "_other_extra_"
    ]) == "text_other_extra_");
    // Double dollar ignored as an environment
    assert("text$$(NAME)".envExpand(["NAME": "not-replaced"]) == "text$(NAME)");

}
