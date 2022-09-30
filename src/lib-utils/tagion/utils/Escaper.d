module tagion.utils.Escaper;

import std.format;
import std.algorithm.iterationi : map;
import std.array : join;

@safe 
struct Excaper(S) if (isInputRange!S && is(ElementType!S : const(char))) {
    protected {
char escape_char;
    S range;
}
    @disable this();
    this(S range) @nogc {
    this.range = range;
}

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

    enum special_chars="ntr'\"\\";
    enum code_esc_special_chars=format("enum code_esc_special=%s;", 
special_chars.map!((char c) => '\'~c));

//    pragma(msg, code_esc_special_chars);
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
