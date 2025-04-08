module tagion.wasm.WastTokenizer;

import std.traits;
import std.range;
import std.format;
import std.exception : assumeWontThrow;
import tagion.basic.Debug;
import tagion.utils.convert : convert;
import tagion.basic.Debug;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmException;
import std.array;
import std.algorithm;
import std.conv : to;

@safe:
class WastTokenizerException : WasmException {
    WastTokenizer tokenizer;
    this(string msg,
            ref WastTokenizer tokenizer,
            string file = __FILE__,
            size_t line = __LINE__) pure nothrow {
        this.tokenizer = tokenizer;
        super(msg, file, line);
    }
}

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

enum Begin_Comment = "(;";
enum End_Comment = ";)";

enum token_types = [EnumMembers!TokenType].map!(e => e.to!string).array;

@nogc pure nothrow {
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

struct WastTokenizer {
    uint error_count;
    uint max_errors;
    string toString() const pure nothrow @trusted {
        import std.exception : assumeWontThrow;
        import std.format;

        return assumeWontThrow(format("%s:%s:%d:%d", token, type, line, line_pos));

    }

    void check(const bool flag, string msg, string file = __FILE__, const size_t code_line = __LINE__) pure {
        if (!flag) {
            throw e = new WastTokenizerException(msg, this, file, code_line);
        }
    }

    bool valid(const bool flag, string msg = null, string file = __FILE__, const size_t code_line = __LINE__) nothrow {
        import std.stdio;

        if (!flag) {
            error_count++;
            import tagion.utils.Term;

            const _line = getLine;
            assumeWontThrow((() {
                    writefln("Error:%s %s:%s:%d:%d", msg, token, type, line, line_pos);
                    writefln("%s", _line);
                    writefln("%(%c%)%s^%s", Chars.SPACE.repeat(line_pos), RED, RESET);
                    writefln("%s:%d", file, code_line);
                    wasm_verbose.println("%s", e);
                })());
        }
        return flag;
    }

    void error(Exception e) nothrow {
        this.e = e;
        valid(false, e.msg, e.file, e.line);
    }

    /**
    * This is used to drops all scope '( ... )' in case of parse error
    */
    void dropScopes() pure nothrow {
        void innerScope() nothrow {
            if (type is TokenType.BEGIN) {
                takeToken;
                while (!empty && type !is TokenType.END) {
                    takeToken;
                    innerScope;
                }
                takeToken;
                innerScope;
            }
        }

        while (!empty && type !is TokenType.BEGIN && type !is TokenType.END) {
            takeToken;
        }
        innerScope;
    }

    unittest {
        import std.stdio;
        import std.algorithm;

        const text = "( word1 ( word2 ( word3 ) ( word4 word5 ) ) )";
        {
            auto r = WastTokenizer(text);
            r.nextToken;
            assert(r.token == "word1");
            r.dropScopes;
            assert(equal(r.map!(t => t.token), [")"]));
        }
        {
            auto r = WastTokenizer(text);
            iota(3).each!(n => r.nextToken);
            assert(r.token == "word2");
            r.dropScopes;
            assert(equal(r.map!(t => t.token), [")", ")"]));
        }
        {
            auto r = WastTokenizer(text);
            iota(5).each!(n => r.nextToken);
            assert(r.token == "word3");
            r.dropScopes;
            assert(equal(r.map!(t => t.token), [")", "(", "word4", "word5", ")", ")", ")"]));
        }
        {
            auto r = WastTokenizer(text);
            iota(8).each!(n => r.nextToken);
            assert(r.token == "word4");
            r.dropScopes;
            assert(equal(r.map!(t => t.token), [")", ")", ")"]));
        }
    }

    void expect(const TokenType t, string file = __FILE__, const size_t code_line = __LINE__) nothrow {
        valid(type is t, assumeWontThrow(format("Expected %s but got %s", t, type)), file, code_line);

    }

    enum hex_prefix = "0x";
    T get(T)() nothrow if (isIntegral!T) {
        try {
            return token.convert!T;
        }
        catch (Exception e) {
            valid(false, e.msg);
        }
        return T.init;
    }

    T get(T)() nothrow if (isFloatingPoint!T) {
        try {
            return token.convert!T;
        }
        catch (Exception e) {
            valid(false, e.msg);
        }
        return T.init;

    }

    bool set(T)(ref T val) nothrow {
        try {
            static if (isIntegral!T) {
                val = token.convert!T;
            }
            else static if (isFloatingPoint!T) {
                val = token.convert!T;
            }
            else static if (is(T == string)) {
                val = token;
            }
            else {
                static assert(0, T.stringof ~ " not supported");
            }
        }
        catch (Exception) {
            return false;
        }
        return true;
    }

    string getText() nothrow {
        valid(type == TokenType.STRING, "Text string expected");
        return token.stripQuotes;
    }

    private string text;
    string token;
    uint line;
    uint begin_pos;
    uint pos;
    uint start_line_pos;
    Exception e;
    void nextToken() pure {
        takeToken;
        check(error_count < max_errors, format("Error count exceeds %d", max_errors));
    }

    @nogc pure nothrow {
        this(string text, const uint max_errors = 10) {
            line = 1;
            this.text = text;
            this.max_errors = max_errors;
            popFront;
        }

        bool empty() const {
            return begin_pos >= text.length;
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

        bool takeMatch(string match) {
            string nextPart() {
                if (match.length + pos > text.length) {
                    return null;
                }
                return text[pos .. pos + match.length];
            }

            while (pos < text.length) {
                next;
                if (nextPart == match) {
                    pos += match.length;
                    return true;
                }
            }
            return false;
        }

        unittest {

            const text = "xxx \n xxyzk";
            {
                auto r = WastTokenizer(text);
                const test = r.takeMatch("zzz");
                assert(!test);
            }
            {
                auto r = WastTokenizer(text);
                const test = r.takeMatch("xyz");
                assert(test);
                assert(r.text[r.pos .. $] == "k");
            }
        }

        void nextUntil(string fun, string paramName = "a")() {
            import std.format;

            enum code = format(q{
                alias goUntil=(%1$s) => %2$s; 
                while((pos < text.length) && goUntil(text[pos])) {
                     next;
                }
            }, paramName, fun);
            mixin(code);
        }

        uint line_pos() const {
            return begin_pos - start_line_pos;
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
            begin_pos = pos;
            with (Chars) {
                switch (currentChar) {
                case PARENTHESES_BEGIN:
                    next;
                    if (!empty && text[pos] == SEMICOLON) {
                        next;
                        takeMatch(End_Comment);
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
        private void takeToken() {
            do {
                popFront;
            }
            while (type == TokenType.COMMENT);
        }

        void trim() {
            nextUntil!q{a.isInvisible};
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

        string getLine() const @nogc {
            import std.string;

            const result = text[start_line_pos .. $];
            const eol = result.indexOf('\n');
            if (eol < 0) {
                return result[0 .. $];
            }
            return result[0 .. eol];
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
