module tagion.utils.Escaper;

import std.format;
import std.algorithm.iteration : map, joiner;
import std.array : join;
import std.range.primitives : isInputRange;
//import std.range.primitives : ElementType;
import std.traits : ForeachType;
import std.range;

    
enum special_chars = "ntr'\"\\";
enum code_esc_special_chars = 
format(q{enum code_esc_special="%s";},
                        zip('\\'.repeat(special_chars.length),
                        special_chars.map!(c => cast(char)c))
                        .map!(m => only(m[0],m[1])).array.join);
pragma(msg, code_esc_special_chars);
mixin(code_esc_special_chars);

@safe
struct Escaper(S) if (isInputRange!S && is(ForeachType!S : const(char))) {
    protected {
        char escape_char;
        S range;
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
            if (escape_char is char.init) {
                return escape_char;
            }
            return cast(char)range.front;
        }
 
       /+ 
    void popFront() const {
        if (escape_char is char.init) {
            switch(range.front) {
            static foreach(c; esc_char) {
                
            }
        }
            char next_char(const char c) {
                
                switch(c) {
                case '\n': escape_char='n';
            }
            }
        }


    }
+/
}
}

@safe
Escaper!S escaper(S)(S range) {
    return Escaper!S(range);
}

@safe
unittest {
    import std.stdio;
    auto test=escaper("text");
    pragma(msg, isInputRange!(typeof("text")));
    pragma(msg, ForeachType!(typeof("text")));
}
