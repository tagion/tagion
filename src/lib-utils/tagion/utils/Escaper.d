module tagion.utils.Escaper;

import std.format;
import std.algorithm.iteration : map;
import std.array : join;
 import std.range.primitives : isInputRange;
import std.range.primitives : ElementType;


@safe
struct Escaper(S) if (isInputRange!S && is(ElementType!S : const(char))) {
    protected {
        char escape_char;
        S range;
    }
    @disable this();
    this(S range) @nogc {
        this.range = range;
    }
        enum special_chars = "ntr'\"\\";
        enum x =
            special_chars.map!(c => c).join;
    @nogc pure nothrow {
        bool empty() const {
            return range.empty;
        }

        char front() const {
            if (escape_char is char.init) {
                return escape_char;
            }
            return range.front;
        }
 
enum code_esc_special_chars = format("enum code_esc_special=%s;",
                    special_chars.map!(c => c));

            pragma(msg, code_esc_special_chars);
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
    return Escaper(S)(range);
}

@safe
unittest {
    import std.stdio;
  //  auto test=escaper("text");
    pragma(msg, isInputRange!(typeof("text")));
    pragma(msg, ElementType!(typeof("text")));
}
