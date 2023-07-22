module tagion.wasm.WastTokenizer;

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

    bool isInvisiable(const char ch) {
        with (Chars) {
            return (ch <= SPACE) || (ch == DEL);
        }
    }
}

@safe
struct WastTokenizer {
    string toString() const pure nothrow @trusted {
        import std.exception : assumeWontThrow;
        import std.format;

        return assumeWontThrow(format("%s:%s:%d:%d", token, type, line, line_pos));

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

        ref const(WastTokenizer) front() const @trusted {
            return this;
        }

        void next() {
            if (!empty) {
                pos++;
            }
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
                case PARENTHESES_END:
                    pos++;
                    break;

                case SEMICOLON:
                    pos++;
                    while (!empty && text[pos] != SEMICOLON) {
                        pos++;
                    }
                    next;
                    break;

                case DOUBLE_QUOTE:
                    pos++;
                    while (!empty && text[pos] != DOUBLE_QUOTE) {
                        pos++;
                    }
                    next;
                    break;
                default:
                    while (!empty && text[pos].isWordChar) {
                        pos++;
                    }
                }
                token = text[begin_pos .. pos];
            }
        }

        void trim() {
            while (!empty && text[pos].isInvisiable) {
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
    import tagion.basic.basic : unitfile;
    import std.file : readText;

    immutable(string) wast_text;
    shared static this() {
        //wast_text = "i32.wast".unitfile.readText;
        //wast_text = "f32.wast".unitfile.readText;
        //wast_text = "i64.wast".unitfile.readText;
        wast_text = "f64.wast".unitfile.readText;
    }
}

@safe
unittest {
    import tagion.basic.basic;

    import std.stdio;

    //    writefln("Unitfile file %s", mangle!(WastParser)(""));
    //writefln("Unitfile file %s", wast_text);
    auto r = WastTokenizer(wast_text);
    while (!r.empty) {
        //        writefln("<%s:%d:%s:%s>", r.line, r.line_pos, r.type, r.token);
        r.popFront;
    }
}
