module tagion.wasm.WastTokenizer;

import std.traits;
import tagion.basic.Debug;

enum Chars : char {
    NUL = '\0',
    SPACE = char(0x20),
    DOUBLE_QUOTE = '"',
    PARENTHESES_BEGIN = '(',
    PARENTHESES_END = ')',
    DEL = char(127),
    NEWLINE = '\n',
    SEMICOLON = ';',
}

enum TokenType {
    EOF,
    BEGIN,
    END,
    COMMENT,
    WORD,
    STRING,
}

@safe @nogc pure nothrow {
    bool isWordChar(const char ch) {
        with (Chars) {
            return (ch > SPACE) && (ch < DEL) &&
                (ch != DOUBLE_QUOTE) && (ch != PARENTHESES_BEGIN) && (ch != PARENTHESES_END);
        }
    }

    bool isStringChar(const char ch) {
        with (Chars) {
            return (ch >= SPACE) && (ch < DEL) && (ch != DOUBLE_QUOTE);
        }
    }

    bool isInvisible(const char ch) {
        with (Chars) {
            return (ch <= SPACE) || (ch == DEL);
        }
    }

    string stripQuotes(string text) {
        if (text.length > 2) {
            return text[text[0] == '"' .. $ - (text[$ - 1] == '"')];
        }
        return text;
    }
}

@safe
struct WastTokenizer {
    string toString() const pure nothrow @trusted {
        import std.exception : assumeWontThrow;
        import std.format;

        return assumeWontThrow(format("%s:%s:%d:%d", token, type, line, line_pos));

    }

    void check(const bool flag, string msg = null, string file = __FILE__, const size_t code_line = __LINE__) nothrow {
        import std.exception : assumeWontThrow;
        import std.stdio;

        if (!flag) {
            assumeWontThrow((() {
                    writefln("Error:%s %s:%s:%d:%d", msg, token, type, line, line_pos);
                    writefln("%s:%d", file, code_line);
                })());

        }
    }

    T get(T)() nothrow if (isIntegral!T) {
        import std.algorithm.comparison : min;
        import std.conv;

        try {
            enum hex_prefix = "0x";
            if (token[0 .. min(hex_prefix.length, $)] == hex_prefix) {
                return cast(T)(token[hex_prefix.length .. $].to!(Unsigned!T)(16));
            }
            return token.to!T;
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        return T.init;
    }

    T get(T)() nothrow if (isFloatingPoint!T) {
        import std.format;

        try {
            const spec = singleSpec("%f");
            auto number = token;
            return unformatValue!T(number, spec);
        }
        catch (Exception e) {
            check(false, e.msg);
        }
        return T.init;

    }

    private string text;
    string token;
    uint line;
    uint pos;
    uint start_line_pos;
    @nogc pure nothrow {
        this(string text) {
            line = 1;
            this.text = text;
            popFront;
        }

        bool empty() const {
            return pos >= text.length;
        }

        const(WastTokenizer) front() const {
            return this;
        }

        char next() {
            if (!empty) {
                scope (exit) {
                    pos++;
                }

                if (text[pos] == Chars.NEWLINE) {
                    start_line_pos = pos + 1;
                    line++;
                }
                return text[pos];
            }
            return Chars.NUL;
        }

        void nextUntil(string fun, string paramName = "a")() {
            import std.format;

            enum code = format(q{
                alias goUntil=(%1$s) => %2$s; 
                while(!empty && goUntil(text[pos])) {
                next;
                  // empty
                }
            }, paramName, fun);
            mixin(code);
        }

        uint line_pos() const {
            return pos - start_line_pos;
        }

        TokenType type() const {
            if (empty) {
                return TokenType.EOF;
            }
            with (Chars) {
                switch (token[0]) {
                case NUL:
                    return TokenType.EOF;
                    case PARENTHESES_BEGIN:
                    if (token.length > 1 && token[1] == SEMICOLON) {
                        return TokenType.COMMENT;
                    }
                    return TokenType.BEGIN;
                    case PARENTHESES_END:
                    return TokenType.END;
                    case SEMICOLON:
                    return TokenType.COMMENT;
                    case DOUBLE_QUOTE:
                    return TokenType.STRING;
                    default:
                    return TokenType.WORD;
                }
            }
            assert(0);
        }

        void popFront() {
            trim;
            const begin_pos = pos;
            with (Chars) {
                switch (currentChar) {
                case PARENTHESES_BEGIN:
                    next;
                    if (!empty && text[pos] == SEMICOLON) {
                        next;
                        nextUntil!q{a != Chars.PARENTHESES_END};
                        next;
                    }
                    break;
                case PARENTHESES_END:
                    next;
                    break;

                case SEMICOLON:
                    next;
                    nextUntil!q{a == Chars.SEMICOLON};
                    nextUntil!q{a != Chars.NEWLINE};
                    next;
                    break;

                case DOUBLE_QUOTE:
                    next;
                    nextUntil!q{a != Chars.DOUBLE_QUOTE};
                    next;
                    break;
                default:
                    nextUntil!q{a.isWordChar};
                }
                token = text[begin_pos .. pos];
            }
        }

        // Like popFront exception that it skips the Comment token
        void nextToken() {
            do {
                popFront;
            }
            while (type == TokenType.COMMENT);
        }

        void trim() {
            nextUntil!q{a.isInvisible};
            version (none)
                while (!empty && text[pos].isInvisible) {
                if (text[pos] == Chars.NEWLINE) {
                    start_line_pos = pos + 1;
                    line++;
                }
                pos++;
            }
        }

        char currentChar() const {
            if (!empty) {
                return text[pos];
            }
            return '\0';
        }

        WastTokenizer save() {
            return this;
        }
    }
}

version (unittest) {
    import std.file : readText;
    import tagion.basic.basic : unitfile;

    immutable(string) wast_text;
    shared static this() {
        //        wast_text = "i32.wast".unitfile.readText;
        //wast_text = "f32.wast".unitfile.readText;
        //wast_text = "i64.wast".unitfile.readText;
        // wast_text = "f64.wast".unitfile.readText;
        //wast_text = "f32_cmp.wast".unitfile.readText;
        //wast_text = "f64_cmp.wast".unitfile.readText;
        //wast_text = "float_exprs.wast".unitfile.readText;
        //wast_text = "unreachable.wast".unitfile.readText;
        //wast_text = "float_literals.wast".unitfile.readText;
        //wast_text = "float_memory.wast".unitfile.readText;
        //wast_text = "float_misc.wast".unitfile.readText;
        //wast_text = "conversions.wast".unitfile.readText;
        //wast_text = "endianness.wast".unitfile.readText;
        //wast_text = "traps.wast".unitfile.readText;
        //wast_text = "runaway-recursion.wast".unitfile.readText;
        //wast_text = "nan-propagation.wast".unitfile.readText;
        // wast_text = "forward.wast".unitfile.readText;
        //wast_text = "func_ptrs.wast".unitfile.readText;
        //        wast_text = "functions.wast".unitfile.readText;
        /// -- wast_text = "has_feature.wast".unitfile.readText;
        //wast_text = "imports.wast".unitfile.readText;
        //wast_text = "int_exprs.wast".unitfile.readText;
        //wast_text = "int_literals.wast".unitfile.readText;
        //wast_text = "labels.wast".unitfile.readText;
        //        wast_text = "left-to-right.wast".unitfile.readText;
        //wast_text = "memory_redundancy.wast".unitfile.readText;
        //        wast_text = "memory_trap.wast".unitfile.readText;
        //wast_text = "memory.wast".unitfile.readText;
        //wast_text = "resizing.wast".unitfile.readText;
        //wast_text = "select.wast".unitfile.readText;
        //wast_text = "store_retval.wast".unitfile.readText;
        wast_text = "switch.wast".unitfile.readText;
    }
}

version (WAST) @safe
unittest {
    import std.stdio;
    import tagion.basic.basic;

    //    writefln("Unitfile file %s", mangle!(WastParser)(""));
    //writefln("Unitfile file %s", wast_text);
    auto r = WastTokenizer(wast_text);
    while (!r.empty) {
        //        writefln("Token %s", r);
        r.popFront;
    }
}
