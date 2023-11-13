module tagion.utils.Escaper;

import std.algorithm.iteration : joiner, map;
import std.array : join;
import std.format;
import std.range;
import std.range.primitives : isInputRange;
import std.string : indexOf;
import std.traits : ForeachType;

enum special_chars = "ntr'\"\\"; /// List of special chars which will be escapes

enum code_esc_special_chars =
    format(q{enum escaped_special_chars="%s";},
            zip('\\'.repeat(special_chars.length),
            special_chars.map!(c => cast(char) c))
            .map!(m => only(m[0], m[1])).array.join);
mixin(code_esc_special_chars);

/** 
    Range which takes a range of chars and converts to a range with added esc '\\' 
infront of a list fo special chars.
*/
@safe
struct Escaper(S) if (isInputRange!S && is(ForeachType!S : const(char))) {
    protected {
        char escape_char;
        S range;
        ESCMode mode;
    }
    enum ESCMode {
        none, /// Normal  char
        esc, /// Esc char '\'
        symbol /// Escaped symbol
    }

    @disable this();
    this(S range) pure {
        this.range = range;
    }

    pure {
        bool empty() const {
            return range.empty;
        }

        char front() {
            prepareEscape;
            with (ESCMode) final switch (mode) {
            case none:
                return cast(char) range.front;
            case esc:
                return '\\';
            case symbol:
                return escape_char;
            }
            assert(0);
        }

        void popFront() {
            with (ESCMode) final switch (mode) {
            case none:
                prepareEscape;
                range.popFront;
                break;
            case esc:
                mode = symbol;
                break;
            case symbol:
                mode = none;
                range.popFront;
            }
        }

        void prepareEscape() {
            if (mode is ESCMode.none) {
                const index = escaped_special_chars.indexOf(range.front);
                if (index >= 0) {
                    mode = ESCMode.esc;
                    escape_char = special_chars[index];
                }
            }
        }
    }
}

@safe
Escaper!S escaper(S)(S range) {
    return Escaper!S(range);
}

///Examples: Escaping a text range
@safe
unittest {
    //    import std.stdio;
    import std.algorithm.comparison : equal;

    { /// Simple string unchanged
        auto test = escaper("text");
        assert(equal(test, "text"));
    }
    { /// Unsert esc in front of control chars
        auto test = escaper("t\n #name \r");
        assert(equal(test, r"t\n #name \r"));
    }

    { /// Inserts esc in front of  "
        auto test = escaper("t \"#name\" ");
        assert(equal(test, `t \"#name\" `));
    }
}
