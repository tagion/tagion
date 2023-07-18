module tagion.wasm.WastParser;

import tagion.basic.Debug;

enum Chars : char {
    SPACE = char(0x20),
    DOUBLE_QUOTE = '"',
    PARENTHESES_BEGIN = '(',
    PARENTHESES_END = ')',
    DEL = char(127),
    NEWLINE = '\n',
    SEMICOLON = ';',
}

@safe
bool isWordChar(const char ch) pure nothrow {
    with (Chars) {
        return (ch > SPACE) && (ch < DEL) &&
            (ch != DOUBLE_QUOTE) && (ch != PARENTHESES_BEGIN) && (ch != PARENTHESES_END);
    }
}

@safe
bool isStringChar(const char ch) pure nothrow {
    with (Chars) {
        return (ch >= SPACE) && (ch < DEL) && (ch != DOUBLE_QUOTE);
    }
}

@safe
bool isInvisiable(const char ch) pure nothrow {
    with (Chars) {
        return (ch <= SPACE) || (ch == DEL);
    }
}

@safe
struct WastParser {
    static class WastToken {
        string word;
        string name;
        WastToken[] list;
    }

    private string text;
    this(string text) @nogc pure nothrow {
        this.text = text;
    }

    @nogc
    struct TokenRange {
        string text;
        string token;
        uint line;
        uint pos;
        int max_count;
        this(string text) pure nothrow {
            line = 1;
            this.text = text;
        }

        bool empty() const pure nothrow {
            return pos >= text.length;
        }

        void next() pure nothrow {
            if (!empty) {
                pos++;
            }
        }

        string nextToken() pure nothrow {
            max_count--;
            assert(max_count >= 0);
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
                __write("[%d..%d]=%s", begin_pos, pos, text[begin_pos .. pos]);
                return token = text[begin_pos .. pos];
            }
        }

        void trim() pure nothrow {
            while (!empty && text[pos].isInvisiable) {
                if (text[pos] == Chars.NEWLINE) {
                    line++;
                }
                pos++;
            }
        }

        char currentChar() const pure nothrow {
            if (!empty) {
                return text[pos];
            }
            return '\0';
        }

    }
}

version (unittest) {
    import tagion.basic.basic : unitfile;
    import std.file : readText;

    immutable(string) wast_text;
    shared static this() {
        wast_text = "i32.wast".unitfile.readText;
    }
}

void func() {
}

@safe
unittest {
    import tagion.basic.basic;

    import std.stdio;

    //    writefln("Unitfile file %s", mangle!(WastParser)(""));
    //writefln("Unitfile file %s", wast_text);
    auto r = WastParser.TokenRange(wast_text);
    r.max_count = 2000;
    while (!r.empty) {
        const token = r.nextToken;
        writefln("<%s:%d:%s>", r.line, r.pos, r.token);
    }
}
