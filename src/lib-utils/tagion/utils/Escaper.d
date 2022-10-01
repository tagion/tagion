module tagion.utils.Escaper;

import std.format;
import std.algorithm.iteration : map, joiner;
import std.array : join;
import std.range.primitives : isInputRange;

//import std.range.primitives : ElementType;
import std.traits : ForeachType;
import std.range;
import std.string : indexOf;

enum special_chars = "ntr'\"\\";
enum code_esc_special_chars =
    format(q{enum escaped_special_chars="%s";},
            zip('\\'.repeat(special_chars.length),
            special_chars.map!(c => cast(char) c))
            .map!(m => only(m[0], m[1])).array.join);
//pragma(msg, code_esc_special_chars);
mixin(code_esc_special_chars);

/** 
    Range which takes a range of char and translate it to raw range of char 
*/
@safe
struct Escaper(S) if (isInputRange!S && is(ForeachType!S : const(char))) {
    protected {
        char escape_char;
        S range;
        ESCMmode mode;
    }
    enum ESCMode {
        none, /// Normal  char
     esc, /// Esc char '\'
        symbol /// Escaped symbol
    }
    @disable this();
    this(S range) @nogc {
        this.range = range;
    }

    pure {
        bool empty() const {
            return range.empty;
        }

        char front() const {
        with(ESCMode) final switch(mode) {
        case none:
            return range.front;
        case esc:
            return '\';
            case symbol;
            return escape_char;
        }
        assert(0);
       }

        void popFront() {
            with(ESCMode) final switch(mode) {
            case none:
                const index = escaped_special_chars.indexOf(range.front);
                if (index < 0) {
                    mode=esc;

                    escape_char = special_chars[index];
                }
                range.popFront;
            break;
            case esc:
                mode=symbol;
                break;
            case symbol:
                mode=none;
            }
        }
    }
}

@safe
Escaper!S escaper(S)(S range) {
    return Escaper!S(range);
}

///Examples: Escaping a text
@safe
unittest {
    import std.stdio;
    import std.algorithm.comparison : equal;

    { //
        auto test = escaper("text");
        writefln("test = '%s'\n", test);
        assert(equal(test, "text"));
    }
    {
        auto test = escaper("t\n \"#name\" \r");
        writefln("test2=%(<%s> %)", test.take(5));
    }
    pragma(msg, isInputRange!(typeof("text")));
    pragma(msg, ForeachType!(typeof("text")));
}
