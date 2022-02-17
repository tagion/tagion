module tagion.script.ScriptParser;

import std.uni : toUpper;
import std.traits : EnumMembers;
import tagion.basic.Message : message;

struct Token {
    string name;
    uint line;
    uint pos;
    string toText() @safe const {
        if (line is 0) {
            return name;
        }
        else {
            return message("%s:%s:%s", line, pos, name);
        }
    }
}

@safe
struct ScriptParser {
    immutable(string) source;
    immutable(string) file;
    this(string source, string file = null) {
        this.source = source;
        this.file = file;
    }

    Range opSlice() const {
        return Range(source);
    }

    struct Range {
        immutable(string) source;
        protected {
            size_t _begin_pos; /// Begin position of a token
            size_t _end_pos; /// End position of a token
            uint _line; /// Line number
            size_t _line_pos; /// Position of the current line
            uint _current_line; /// Line number of the current token
            size_t _current_pos; /// Position of the token in the current line
            bool _eos; /// Markes end of stream
        }
        this(string source) {
            _line = 1;
            this.source = source;
            //            trim;
            popFront;
        }

        @property const pure nothrow {
            uint line() {
                return _current_line;
            }

            uint pos() {
                return cast(uint)(_begin_pos - _current_pos);
            }

            immutable(string) front() {
                return source[_begin_pos .. _end_pos];
            }

            bool empty() {
                return _eos;
            }

            immutable(string) grap(const size_t begin, const size_t end)
            in {
                assert(begin <= end);
            }
            do {
                return source[begin .. end];
            }

        }

        @property void popFront() {
            _eos = (_end_pos == source.length);
            trim;
            _end_pos = _begin_pos;
            _current_line = _line;
            _current_pos = _line_pos;
            if (_end_pos < source.length) {
                if (source[_end_pos] is '(') {
                    _end_pos++;
                    while (_end_pos < source.length) {
                        const eol = is_newline(source[_end_pos .. $]);
                        if (eol) {
                            _end_pos += eol;
                            _line_pos = _end_pos;
                            _line++;
                        }
                        else if (source[_end_pos] is ')') {
                            _end_pos++;
                            break;
                        }
                        else {
                            _end_pos++;
                        }
                    }
                }
                else if (source[_end_pos] is '"' || source[_end_pos] is '\'') {
                    const quote = source[_begin_pos];
                    _end_pos++;
                    bool escape;
                    while (_end_pos < source.length) {
                        const eol = is_newline(source[_end_pos .. $]);
                        if (eol) {
                            _end_pos += eol;
                            _line_pos = _end_pos;
                            _line++;
                        }
                        else {
                            if (!escape) {
                                escape = source[_end_pos] is '\\';
                            }
                            else {
                                escape = false;
                            }
                            if (!escape && (source[_end_pos] is quote)) {
                                _end_pos++;
                                break;
                            }
                            _end_pos++;
                        }
                    }
                }
                else {
                    while ((_end_pos < source.length) && is_none_white(source[_end_pos])) {
                        _end_pos++;
                    }
                }
            }
            if (_end_pos is _begin_pos) {
                _eos = true;
            }
        }

        protected void trim() {
            scope size_t eol;
            _begin_pos = _end_pos;
            while (_begin_pos < source.length) {
                if (is_white_space(source[_begin_pos])) {
                    _begin_pos++;
                }
                else if ((eol = is_newline(source[_begin_pos .. $])) !is 0) {
                    _begin_pos += eol;
                    _line_pos = _begin_pos;
                    _line++;
                }
                else {
                    break;
                }
            }
        }
    }

    static bool is_white_space(immutable char c) @safe pure nothrow {
        return ((c is ' ') || (c is '\t'));
    }

    static bool is_none_white(immutable char c) @safe pure nothrow {
        return (c !is ' ') && (c !is '\t') && (c !is '\n') && (c !is '\r');
    }

    static size_t is_newline(string str) pure {
        if ((str.length > 0) && (str[0] == '\n')) {
            if ((str.length > 1) && ((str[0 .. 2] == "\n\r") || (str[0 .. 2] == "\r\n"))) {
                return 2;
            }
            return 1;
        }
        return 0;
    }

}

unittest {
    import std.string : join;

    immutable src = [
        ": test_comment ( a b -- )", // 1
        "+ ( some comment ) ><>A ", // 2
        "( line comment -- ) ", // 3
        "X", // 4
        "( newline", // 5
        "  comment )", // 6
        "  ( multi line  ", // 7
        " 0x1222 XX 122 test", // 8
        ") &  ", // 9
        "___ ( multi line  ", // 10
        "\t 0xA-- XX 122 test", // 11
        "  ) &&&", // 12
        "; ( end function )", // 13
        "*-&  ", // 14
        ` "text1" `, // 15
        " 'text2' ", // 16
        ` 'text3 text4' `, // 17
        " '' ", // 18
        ";", // 19
        "   ", // 20
        ": next_test", // 21
        " + ", // 22
        ";", // 23
        "   "
    ].join("\n") // 24

    ;

    struct Token {
        uint line;
        size_t pos;
        string token;
    }

    immutable(Token[]) tokens =
        [
            {line: 1, pos: 0, token: ":"},
            {line: 1, pos: 2, token: "test_comment"},
            {line: 1, pos: 15, token: "( a b -- )"},
            {line: 2, pos: 0, token: "+"},
            {line: 2, pos: 2, token: "( some comment )"},
            {line: 2, pos: 19, token: "><>A"},
            {line: 3, pos: 0, token: "( line comment -- )"},
            {line: 4, pos: 0, token: "X"},
            {line: 5, pos: 0, token: ["( newline", "  comment )"].join("\n")},
            {line: 7, pos: 2, token: ["( multi line  ", " 0x1222 XX 122 test", ")"].join("\n")},
            {line: 9, pos: 2, token: "&"},
            {line: 10, pos: 0, token: "___"},
            {line: 10, pos: 4, token: ["( multi line  ", "\t 0xA-- XX 122 test", "  )"].join(
                    "\n")},
            {line: 12, pos: 4, token: "&&&"},
            {line: 13, pos: 0, token: ";"},
            {line: 13, pos: 2, token: "( end function )"},
            {line: 14, pos: 0, token: "*-&"},
            {line: 15, pos: 1, token: `"text1"`},
            {line: 16, pos: 1, token: "'text2'"},
            {line: 17, pos: 1, token: "'text3 text4'"},
            {line: 18, pos: 1, token: "''"},
            {line: 19, pos: 0, token: ";"},
            {line: 21, pos: 0, token: ":"},
            {line: 21, pos: 2, token: "next_test"},
            {line: 22, pos: 1, token: "+"},
            {line: 23, pos: 0, token: ";"},
        ];

    const parser = ScriptParser(src);
    //    uint count;
    // auto range_1=parser[];

    import std.stdio;

    //     while (!range_1.empty) {
    // //    foreach(t; parser[]) {
    // //        const x=t.token;
    //         writefln("{line : %d, pos : %d, token : \"%s\"},", range_1.line, range_1.pos, range_1.front);
    //         range_1.popFront;
    //     }
    auto range = parser[];
    foreach (t; tokens) {
        assert(range.line is t.line);
        assert(range.pos is t.pos);
        assert(range.front == t.token);
        assert(!range.empty);
        range.popFront;
    }
    assert(range.empty);
}

enum ScriptKeyword {
    NONE,
    DO,
    LOOP,
    ADDLOOP,
    BEGIN,
    REPEAT,
    UNTIL,
    WHILE,
    LEAVE,
    AGAIN,
    EXIT,
    IF,
    ELSE,
    ENDIF,
    THEN,
    FUNC,
    ENDFUNC,

    I,
    GET,
    COMMENT,
    // Regex tokens
    VAR,
    NUMBER,
    HEX,
    WORD,
    TEXT,
    PUT,
}

enum keywordMap = [
        ScriptKeyword.DO: ScriptKeyword.DO.stringof,
        ScriptKeyword.LOOP: ScriptKeyword.LOOP.stringof,
        ScriptKeyword.ADDLOOP: "+LOOP",
        ScriptKeyword.BEGIN: ScriptKeyword.BEGIN.stringof,
        ScriptKeyword.UNTIL: ScriptKeyword.UNTIL.stringof,
        ScriptKeyword.WHILE: ScriptKeyword.WHILE.stringof,
        ScriptKeyword.REPEAT: ScriptKeyword.REPEAT.stringof,
        ScriptKeyword.LEAVE: ScriptKeyword.LEAVE.stringof,
        ScriptKeyword.AGAIN: ScriptKeyword.AGAIN.stringof,
        ScriptKeyword.EXIT: ScriptKeyword.EXIT.stringof,
        ScriptKeyword.IF: ScriptKeyword.IF.stringof,
        ScriptKeyword.ELSE: ScriptKeyword.ELSE.stringof,
        ScriptKeyword.ENDIF: ScriptKeyword.ENDIF.stringof,
        ScriptKeyword.THEN: ScriptKeyword.THEN.stringof,
        ScriptKeyword.LOOP: ScriptKeyword.LOOP.stringof,
        ScriptKeyword.I: ScriptKeyword.I.stringof,
        ScriptKeyword.BEGIN: ScriptKeyword.BEGIN.stringof,

        ScriptKeyword.FUNC: ":",
        ScriptKeyword.ENDFUNC: ";",
        ScriptKeyword.GET: "@",
    ];

static ScriptKeyword[string] generateLabelMap(const(string[ScriptKeyword]) typemap) {
    ScriptKeyword[string] result;
    foreach (e, label; typemap) {
        if (label.length !is 0) {
            result[label] = e;
        }
    }
    return result;
}

unittest {
    static foreach (E; EnumMembers!ScriptKeyword) {
        with (ScriptKeyword) {
            switch (E) {
            case NONE, NUMBER, HEX, WORD, TEXT, VAR, PUT, COMMENT:
                break;
            default:
                import std.format;

                assert(E in keywordMap, format("TypeMap %s is not defined", E));
            }
        }
    }
}

protected enum _scripttype = [
        "NONE",
        "NUM",
        "I32",
        "U32",
        "I64",
        "U64",
        "STRING",
        "DOC",
        "HIBON"
    ];

private import tagion.basic.Basic : EnumText;

mixin(EnumText!("ScriptType", _scripttype));

@safe
static struct Lexer {
    protected enum ctLabelMap = generateLabelMap(keywordMap);
    import std.regex;

    static Regex!char regex_number() {
        enum _regex_number = regex("^[-+]?[0-9][0-9_]*$");
        return _regex_number;
    }

    static Regex!char regex_word() {
        enum _regex_word = regex(`^[^"]+$`);
        return _regex_word;
    }

    static Regex!char regex_hex() {
        enum _regex_hex = regex("^[-+]?0[xX][0-9a-fA-F_][0-9a-fA-F_]*$");
        return _regex_hex;
    }

    static Regex!char regex_text() {
        enum _regex_text = regex(`^"[^"]*"$`);
        return _regex_text;
    }

    static Regex!char regex_put() {
        enum _regex_put = regex(r"^[+-/\*><%\^\&\|]*!@?$");
        return _regex_put;
    }

    static Regex!char regex_comment() {
        enum _regeax_comment = regex(r"^\([^\)]+\)$");
        return _regeax_comment;
    }

    static Regex!char regex_bound() {
        enum _regex_bound = regex(
                    r"^\w+(\[(0x[0-9a-f][0-9a-f_]*|\d+)\.\.(0x[0-9a-f][0-9a-f_]*|\d+)\])?$");
        return _regex_bound;
    }

    static Regex!char regex_reserved_var() {
        enum _regex_reserved_var = regex(r"^(I|TO)\d{0,2}$");
        return _regex_reserved_var;
    }

    static ScriptType getScriptType(string word) {
        static foreach (TYPE; EnumMembers!ScriptType) {
            static if (TYPE is ScriptType.NUM) {
                if ((word.length >= TYPE.length) &&
                        (word[0 .. TYPE.length] == TYPE) &&
                        (word.match(regex_bound))) {
                    return TYPE;
                }
            }
            else if (word == TYPE) {
                return TYPE;
            }
        }
        return ScriptType.NONE;
    }

    static ScriptKeyword get(string word) {
        ScriptKeyword result;
        with (ScriptKeyword) {
            result = ctLabelMap.get(word, NONE);
            if (result is NONE) {
                if (word.match(regex_number)) {
                    result = NUMBER;
                }
                else if (word.match(regex_hex)) {
                    result = HEX;
                }
                else if (word.match(regex_text)) {
                    result = TEXT;
                }
                else if (word.match(regex_put)) {
                    result = PUT;
                }
                else if (word.match(regex_comment)) {
                    result = COMMENT;
                }
                else if (Lexer.getScriptType(word) !is ScriptType.NONE) {
                    result = VAR;
                }
                else if (word.match(regex_word)) {
                    result = WORD;
                }
            }
        }
        return result;
    }

    unittest {
        with (ScriptKeyword) {
            assert(get("REPEAT") == REPEAT);
            assert(get(`"`) == NONE);
            assert(get("someword") == WORD);
            assert(get("-123_444") == NUMBER);
            assert(get("0x42") == HEX);
        }
    }

    enum {
        SPACE = char(0x20),
        QUATE = char(39),
        DOUBLE_QUATE = '"',
        BACK_QUATE = '`',
        LOCAL_SEPARATOR = ':',
        DEL = char(127)
    }

    static bool is_name_valid(string str) pure {
        foreach (c; str) {
            if ((c <= SPACE) || (c >= DEL) || (c is QUATE) ||
                    (c is DOUBLE_QUATE) || (c is BACK_QUATE) ||
                    (c is LOCAL_SEPARATOR)) {
                return false;
            }
        }
        return true;
    }

    static bool isDeclaration(ScriptKeyword type) pure nothrow {
        with (ScriptKeyword) {
            switch (type) {
            case VAR:
                return true;
            default:
                return false;
            }
        }
        assert(0);
    }
}
