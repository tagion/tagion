module tagion.wasm.WasmParser;

import std.format;
import std.range.primitives : isForwardRange, isInputRange;
import std.traits : EnumMembers;
import std.uni : toUpper;

import tagion.utils.LEB128;

//import tagion.Message : message;

@safe struct Token {
    enum Type {
        NONE,
        COMMENT,
        WORD,
        BRACKET,
        TEXT
    }

    string symbol;
    uint line;
    uint pos;
    Type type;
    string toText() pure const {
        if (line is 0) {
            return symbol;
        }
        else {
            return format("%s:%s:%s", line, pos, symbol);
        }
    }
}

@safe struct Tokenizer {
    immutable(string) source;
    immutable(string) file;
    this(string source, string file = null) {
        this.source = source;
        this.file = file;
    }

    Range opSlice() const {
        return Range(source);
    }

    static assert(isInputRange!Range);
    static assert(isForwardRange!Range);

    @nogc @safe struct Range {
        immutable(string) source;
        protected {
            size_t _begin_pos; /// Begin position of a token
            size_t _end_pos; /// End position of a token
            uint _line; /// Line number
            size_t _line_pos; /// Position of the current line
            uint _current_line; /// Line number of the current token
            size_t _current_pos; /// Position of the token in the current line
            bool _eos; /// Marks end of stream
            Token.Type type;
        }
        this(string source) pure nothrow {
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

            immutable(string) symbol() {
                return source[_begin_pos .. _end_pos];
            }

            immutable(Token) front() {
                return Token(symbol, line, pos, type);
            }

            bool empty() {
                return _eos;
            }

            size_t begin_pos() {
                return _begin_pos;
            }

            size_t end_pos() {
                return _end_pos;
            }

            immutable(string) grap(const size_t begin, const size_t end)
            in {
                assert(begin <= end);
            }
            do {
                return source[begin .. end];
            }

        }

        @property void popFront() pure nothrow {
            _eos = (_end_pos == source.length);
            trim;
            _end_pos = _begin_pos;
            _current_line = _line;
            _current_pos = _line_pos;
            if (_end_pos < source.length) {
                if ((_end_pos + 1 < source.length) && (source[_end_pos .. _end_pos + 2] == "(;")) {
                    type = Token.Type.COMMENT;
                    _end_pos += 2;
                    uint level = 1;
                    while (_end_pos + 1 < source.length) {
                        const eol = is_newline(source[_end_pos .. $]);
                        if (eol) {
                            _end_pos += eol;
                            _line_pos = _end_pos;
                            _line++;
                        }
                        else if (source[_end_pos .. _end_pos + 2] == ";)") {
                            _end_pos += 2;
                            level--;
                            if (level == 0) {
                                break;
                            }
                        }
                        else if (source[_end_pos .. _end_pos + 2] == "(;") {
                            _end_pos += 2;
                            level++;
                        }
                        else {
                            _end_pos++;
                        }
                    }
                }
                else if ((_end_pos + 1 < source.length) && (source[_end_pos .. _end_pos + 2] == ";;")) {
                    type = Token.Type.COMMENT;
                    _end_pos += 2;
                    while ((_end_pos < source.length) && (!is_newline(source[_end_pos .. $]))) {
                        _end_pos++;
                    }
                }
                else if ((source[_end_pos] is '(') || (source[_end_pos] is ')')) {
                    type = Token.Type.BRACKET;
                    _end_pos++;
                }
                else if (source[_end_pos] is '"' || source[_end_pos] is '\'') {
                    type = Token.Type.TEXT;
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
                    while ((_end_pos < source.length)
                            && is_none_white(source[_end_pos]) && (source[_end_pos]!is ')')) {
                        _end_pos++;
                    }
                    type = Token.Type.WORD;
                }
            }
            if (_end_pos is _begin_pos) {
                _eos = true;
            }
        }

        Range save() pure const nothrow @nogc {
            auto result = this;
            //assert(result is this);
            return result;
        }

        protected void trim() pure nothrow {
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

    static size_t is_newline(string str) pure nothrow {
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
        "(module", "(type $0 (func (param f64 f64) (result f64)))",
        "(type $1 (func (param i32 i32) (result i32)))", "(type $2 (func))",
        "(memory $4  2)", "(table $3  1 1 funcref)",
        "(global $5  (mut i32) (i32.const 66560))",
        `(export "memory" (memory $4))`, `(export "add" (func $add))`,
        `(export "while_loop" (func $while_loop))`,
        `(export "_start" (func $_start))`, "", "(func $add (type $0)",
        "  (param $0 f64)", "  (param $1 f64)", "  (result f64)", "  local.get $0",
        "  local.get $1", "  f64.add", "  )", "", "(func $while_loop (type $1)",
        "  (param $0 i32)", "  (param $1 i32)", "  (result i32)",
        "  (local $2 i32)", "  block $block", "    local.get $0",
        "    i32.const 1", "    i32.lt_s", "    br_if $block",
        "    loop $loop", "      local.get $0", "      i32.const -1",
        "      i32.add", "      local.set $2", "      local.get $0",
        "      local.get $1", "      i32.mul", "      local.set $0",
        "      i32.const 34", "      local.set $1", "      block $block_0",
        "        local.get $0", "        i32.const 17", "        i32.eq",
        "        br_if $block_0", "        local.get $0",
        "        i32.const 2", "        i32.div_s", "        i32.const 1",
        "        i32.add", "        local.set $1", "      end ;; $block_0",
        "      local.get $2", "      local.set $0", "      local.get $2",
        "      i32.const 0", "      i32.gt_s", "      br_if $loop",
        "    end ;; $loop", "  end ;; $block", "  local.get $1", "  )", "",
        "(func $_start (type $2)", "  )", "", `;;(custom_section "producers"`,
        ";;  (after code)", `;;  "\01\0cprocessed-by\01\03ldc\061.20.1")`, "", ")"
    ].join("\n");
    // ": test_comment ( a b -- )", // 1
    // "+ ( some comment ) ><>A ",  // 2
    // "( line comment -- ) ",      // 3
    // "X",                         // 4
    // "( newline",                 // 5
    // "  comment )",               // 6
    // "  ( multi line  ",          // 7
    // " 0x1222 XX 122 test",       // 8
    // ") &  ",                     // 9
    // "___ ( multi line  ",        // 10
    // "\t 0xA-- XX 122 test",        // 11
    // "  ) &&&",                   // 12
    // "; ( end function )",        // 13
    // "*-&  ",                     // 14
    // ` "text1" `,                 // 15
    // " 'text2' ",                 // 16
    // ` 'text3 text4' `,           // 17
    // " '' ",                      // 18
    // ";",                         // 19
    // "   ",                       // 20
    // ": next_test",               // 21
    // " + ",                       // 22
    // ";",                         // 23
    // "   "].join("\n")            // 24

    // ;

    // struct Token {
    //     uint line;
    //     size_t pos;
    //     string token;
    // }

    immutable(Token[]) tokens = [
        {line: 1, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 1, pos: 1, symbol: "module", type: Token.Type.WORD},
        {line: 2, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 2, pos: 1, symbol: "type", type: Token.Type.WORD},
        {line: 2, pos: 6, symbol: "$0", type: Token.Type.WORD},
        {line: 2, pos: 9, symbol: "(", type: Token.Type.BRACKET},
        {line: 2, pos: 10, symbol: "func", type: Token.Type.WORD},
        {line: 2, pos: 15, symbol: "(", type: Token.Type.BRACKET},
        {line: 2, pos: 16, symbol: "param", type: Token.Type.WORD},
        {line: 2, pos: 22, symbol: "f64", type: Token.Type.WORD},
        {line: 2, pos: 26, symbol: "f64", type: Token.Type.WORD},
        {line: 2, pos: 29, symbol: ")", type: Token.Type.BRACKET},
        {line: 2, pos: 31, symbol: "(", type: Token.Type.BRACKET},
        {line: 2, pos: 32, symbol: "result", type: Token.Type.WORD},
        {line: 2, pos: 39, symbol: "f64", type: Token.Type.WORD},
        {line: 2, pos: 42, symbol: ")", type: Token.Type.BRACKET},
        {line: 2, pos: 43, symbol: ")", type: Token.Type.BRACKET},
        {line: 2, pos: 44, symbol: ")", type: Token.Type.BRACKET},
        {line: 3, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 3, pos: 1, symbol: "type", type: Token.Type.WORD},
        {line: 3, pos: 6, symbol: "$1", type: Token.Type.WORD},
        {line: 3, pos: 9, symbol: "(", type: Token.Type.BRACKET},
        {line: 3, pos: 10, symbol: "func", type: Token.Type.WORD},
        {line: 3, pos: 15, symbol: "(", type: Token.Type.BRACKET},
        {line: 3, pos: 16, symbol: "param", type: Token.Type.WORD},
        {line: 3, pos: 22, symbol: "i32", type: Token.Type.WORD},
        {line: 3, pos: 26, symbol: "i32", type: Token.Type.WORD},
        {line: 3, pos: 29, symbol: ")", type: Token.Type.BRACKET},
        {line: 3, pos: 31, symbol: "(", type: Token.Type.BRACKET},
        {line: 3, pos: 32, symbol: "result", type: Token.Type.WORD},
        {line: 3, pos: 39, symbol: "i32", type: Token.Type.WORD},
        {line: 3, pos: 42, symbol: ")", type: Token.Type.BRACKET},
        {line: 3, pos: 43, symbol: ")", type: Token.Type.BRACKET},
        {line: 3, pos: 44, symbol: ")", type: Token.Type.BRACKET},
        {line: 4, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 4, pos: 1, symbol: "type", type: Token.Type.WORD},
        {line: 4, pos: 6, symbol: "$2", type: Token.Type.WORD},
        {line: 4, pos: 9, symbol: "(", type: Token.Type.BRACKET},
        {line: 4, pos: 10, symbol: "func", type: Token.Type.WORD},
        {line: 4, pos: 14, symbol: ")", type: Token.Type.BRACKET},
        {line: 4, pos: 15, symbol: ")", type: Token.Type.BRACKET},
        {line: 5, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 5, pos: 1, symbol: "memory", type: Token.Type.WORD},
        {line: 5, pos: 8, symbol: "$4", type: Token.Type.WORD},
        {line: 5, pos: 12, symbol: "2", type: Token.Type.WORD},
        {line: 5, pos: 13, symbol: ")", type: Token.Type.BRACKET},
        {line: 6, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 6, pos: 1, symbol: "table", type: Token.Type.WORD},
        {line: 6, pos: 7, symbol: "$3", type: Token.Type.WORD},
        {line: 6, pos: 11, symbol: "1", type: Token.Type.WORD},
        {line: 6, pos: 13, symbol: "1", type: Token.Type.WORD},
        {line: 6, pos: 15, symbol: "funcref", type: Token.Type.WORD},
        {line: 6, pos: 22, symbol: ")", type: Token.Type.BRACKET},
        {line: 7, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 7, pos: 1, symbol: "global", type: Token.Type.WORD},
        {line: 7, pos: 8, symbol: "$5", type: Token.Type.WORD},
        {line: 7, pos: 12, symbol: "(", type: Token.Type.BRACKET},
        {line: 7, pos: 13, symbol: "mut", type: Token.Type.WORD},
        {line: 7, pos: 17, symbol: "i32", type: Token.Type.WORD},
        {line: 7, pos: 20, symbol: ")", type: Token.Type.BRACKET},
        {line: 7, pos: 22, symbol: "(", type: Token.Type.BRACKET},
        {line: 7, pos: 23, symbol: "i32.const", type: Token.Type.WORD},
        {line: 7, pos: 33, symbol: "66560", type: Token.Type.WORD},
        {line: 7, pos: 38, symbol: ")", type: Token.Type.BRACKET},
        {line: 7, pos: 39, symbol: ")", type: Token.Type.BRACKET},
        {line: 8, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 8, pos: 1, symbol: "export", type: Token.Type.WORD},
        {line: 8, pos: 8, symbol: `"memory"`, type: Token.Type.TEXT},
        {line: 8, pos: 17, symbol: "(", type: Token.Type.BRACKET},
        {line: 8, pos: 18, symbol: "memory", type: Token.Type.WORD},
        {line: 8, pos: 25, symbol: "$4", type: Token.Type.WORD},
        {line: 8, pos: 27, symbol: ")", type: Token.Type.BRACKET},
        {line: 8, pos: 28, symbol: ")", type: Token.Type.BRACKET},
        {line: 9, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 9, pos: 1, symbol: "export", type: Token.Type.WORD},
        {line: 9, pos: 8, symbol: `"add"`, type: Token.Type.TEXT},
        {line: 9, pos: 14, symbol: "(", type: Token.Type.BRACKET},
        {line: 9, pos: 15, symbol: "func", type: Token.Type.WORD},
        {line: 9, pos: 20, symbol: "$add", type: Token.Type.WORD},
        {line: 9, pos: 24, symbol: ")", type: Token.Type.BRACKET},
        {line: 9, pos: 25, symbol: ")", type: Token.Type.BRACKET},
        {line: 10, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 10, pos: 1, symbol: "export", type: Token.Type.WORD},
        {line: 10, pos: 8, symbol: `"while_loop"`, type: Token.Type.TEXT},
        {line: 10, pos: 21, symbol: "(", type: Token.Type.BRACKET},
        {line: 10, pos: 22, symbol: "func", type: Token.Type.WORD},
        {line: 10, pos: 27, symbol: "$while_loop", type: Token.Type.WORD},
        {line: 10, pos: 38, symbol: ")", type: Token.Type.BRACKET},
        {line: 10, pos: 39, symbol: ")", type: Token.Type.BRACKET},
        {line: 11, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 11, pos: 1, symbol: "export", type: Token.Type.WORD},
        {line: 11, pos: 8, symbol: `"_start"`, type: Token.Type.TEXT},
        {line: 11, pos: 17, symbol: "(", type: Token.Type.BRACKET},
        {line: 11, pos: 18, symbol: "func", type: Token.Type.WORD},
        {line: 11, pos: 23, symbol: "$_start", type: Token.Type.WORD},
        {line: 11, pos: 30, symbol: ")", type: Token.Type.BRACKET},
        {line: 11, pos: 31, symbol: ")", type: Token.Type.BRACKET},
        {line: 13, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 13, pos: 1, symbol: "func", type: Token.Type.WORD},
        {line: 13, pos: 6, symbol: "$add", type: Token.Type.WORD},
        {line: 13, pos: 11, symbol: "(", type: Token.Type.BRACKET},
        {line: 13, pos: 12, symbol: "type", type: Token.Type.WORD},
        {line: 13, pos: 17, symbol: "$0", type: Token.Type.WORD},
        {line: 13, pos: 19, symbol: ")", type: Token.Type.BRACKET},
        {line: 14, pos: 2, symbol: "(", type: Token.Type.BRACKET},
        {line: 14, pos: 3, symbol: "param", type: Token.Type.WORD},
        {line: 14, pos: 9, symbol: "$0", type: Token.Type.WORD},
        {line: 14, pos: 12, symbol: "f64", type: Token.Type.WORD},
        {line: 14, pos: 15, symbol: ")", type: Token.Type.BRACKET},
        {line: 15, pos: 2, symbol: "(", type: Token.Type.BRACKET},
        {line: 15, pos: 3, symbol: "param", type: Token.Type.WORD},
        {line: 15, pos: 9, symbol: "$1", type: Token.Type.WORD},
        {line: 15, pos: 12, symbol: "f64", type: Token.Type.WORD},
        {line: 15, pos: 15, symbol: ")", type: Token.Type.BRACKET},
        {line: 16, pos: 2, symbol: "(", type: Token.Type.BRACKET},
        {line: 16, pos: 3, symbol: "result", type: Token.Type.WORD},
        {line: 16, pos: 10, symbol: "f64", type: Token.Type.WORD},
        {line: 16, pos: 13, symbol: ")", type: Token.Type.BRACKET},
        {line: 17, pos: 2, symbol: "local.get", type: Token.Type.WORD},
        {line: 17, pos: 12, symbol: "$0", type: Token.Type.WORD},
        {line: 18, pos: 2, symbol: "local.get", type: Token.Type.WORD},
        {line: 18, pos: 12, symbol: "$1", type: Token.Type.WORD},
        {line: 19, pos: 2, symbol: "f64.add", type: Token.Type.WORD},
        {line: 20, pos: 2, symbol: ")", type: Token.Type.BRACKET},
        {line: 22, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 22, pos: 1, symbol: "func", type: Token.Type.WORD},
        {line: 22, pos: 6, symbol: "$while_loop", type: Token.Type.WORD},
        {line: 22, pos: 18, symbol: "(", type: Token.Type.BRACKET},
        {line: 22, pos: 19, symbol: "type", type: Token.Type.WORD},
        {line: 22, pos: 24, symbol: "$1", type: Token.Type.WORD},
        {line: 22, pos: 26, symbol: ")", type: Token.Type.BRACKET},
        {line: 23, pos: 2, symbol: "(", type: Token.Type.BRACKET},
        {line: 23, pos: 3, symbol: "param", type: Token.Type.WORD},
        {line: 23, pos: 9, symbol: "$0", type: Token.Type.WORD},
        {line: 23, pos: 12, symbol: "i32", type: Token.Type.WORD},
        {line: 23, pos: 15, symbol: ")", type: Token.Type.BRACKET},
        {line: 24, pos: 2, symbol: "(", type: Token.Type.BRACKET},
        {line: 24, pos: 3, symbol: "param", type: Token.Type.WORD},
        {line: 24, pos: 9, symbol: "$1", type: Token.Type.WORD},
        {line: 24, pos: 12, symbol: "i32", type: Token.Type.WORD},
        {line: 24, pos: 15, symbol: ")", type: Token.Type.BRACKET},
        {line: 25, pos: 2, symbol: "(", type: Token.Type.BRACKET},
        {line: 25, pos: 3, symbol: "result", type: Token.Type.WORD},
        {line: 25, pos: 10, symbol: "i32", type: Token.Type.WORD},
        {line: 25, pos: 13, symbol: ")", type: Token.Type.BRACKET},
        {line: 26, pos: 2, symbol: "(", type: Token.Type.BRACKET},
        {line: 26, pos: 3, symbol: "local", type: Token.Type.WORD},
        {line: 26, pos: 9, symbol: "$2", type: Token.Type.WORD},
        {line: 26, pos: 12, symbol: "i32", type: Token.Type.WORD},
        {line: 26, pos: 15, symbol: ")", type: Token.Type.BRACKET},
        {line: 27, pos: 2, symbol: "block", type: Token.Type.WORD},
        {line: 27, pos: 8, symbol: "$block", type: Token.Type.WORD},
        {line: 28, pos: 4, symbol: "local.get", type: Token.Type.WORD},
        {line: 28, pos: 14, symbol: "$0", type: Token.Type.WORD},
        {line: 29, pos: 4, symbol: "i32.const", type: Token.Type.WORD},
        {line: 29, pos: 14, symbol: "1", type: Token.Type.WORD},
        {line: 30, pos: 4, symbol: "i32.lt_s", type: Token.Type.WORD},
        {line: 31, pos: 4, symbol: "br_if", type: Token.Type.WORD},
        {line: 31, pos: 10, symbol: "$block", type: Token.Type.WORD},
        {line: 32, pos: 4, symbol: "loop", type: Token.Type.WORD},
        {line: 32, pos: 9, symbol: "$loop", type: Token.Type.WORD},
        {line: 33, pos: 6, symbol: "local.get", type: Token.Type.WORD},
        {line: 33, pos: 16, symbol: "$0", type: Token.Type.WORD},
        {line: 34, pos: 6, symbol: "i32.const", type: Token.Type.WORD},
        {line: 34, pos: 16, symbol: "-1", type: Token.Type.WORD},
        {line: 35, pos: 6, symbol: "i32.add", type: Token.Type.WORD},
        {line: 36, pos: 6, symbol: "local.set", type: Token.Type.WORD},
        {line: 36, pos: 16, symbol: "$2", type: Token.Type.WORD},
        {line: 37, pos: 6, symbol: "local.get", type: Token.Type.WORD},
        {line: 37, pos: 16, symbol: "$0", type: Token.Type.WORD},
        {line: 38, pos: 6, symbol: "local.get", type: Token.Type.WORD},
        {line: 38, pos: 16, symbol: "$1", type: Token.Type.WORD},
        {line: 39, pos: 6, symbol: "i32.mul", type: Token.Type.WORD},
        {line: 40, pos: 6, symbol: "local.set", type: Token.Type.WORD},
        {line: 40, pos: 16, symbol: "$0", type: Token.Type.WORD},
        {line: 41, pos: 6, symbol: "i32.const", type: Token.Type.WORD},
        {line: 41, pos: 16, symbol: "34", type: Token.Type.WORD},
        {line: 42, pos: 6, symbol: "local.set", type: Token.Type.WORD},
        {line: 42, pos: 16, symbol: "$1", type: Token.Type.WORD},
        {line: 43, pos: 6, symbol: "block", type: Token.Type.WORD},
        {line: 43, pos: 12, symbol: "$block_0", type: Token.Type.WORD},
        {line: 44, pos: 8, symbol: "local.get", type: Token.Type.WORD},
        {line: 44, pos: 18, symbol: "$0", type: Token.Type.WORD},
        {line: 45, pos: 8, symbol: "i32.const", type: Token.Type.WORD},
        {line: 45, pos: 18, symbol: "17", type: Token.Type.WORD},
        {line: 46, pos: 8, symbol: "i32.eq", type: Token.Type.WORD},
        {line: 47, pos: 8, symbol: "br_if", type: Token.Type.WORD},
        {line: 47, pos: 14, symbol: "$block_0", type: Token.Type.WORD},
        {line: 48, pos: 8, symbol: "local.get", type: Token.Type.WORD},
        {line: 48, pos: 18, symbol: "$0", type: Token.Type.WORD},
        {line: 49, pos: 8, symbol: "i32.const", type: Token.Type.WORD},
        {line: 49, pos: 18, symbol: "2", type: Token.Type.WORD},
        {line: 50, pos: 8, symbol: "i32.div_s", type: Token.Type.WORD},
        {line: 51, pos: 8, symbol: "i32.const", type: Token.Type.WORD},
        {line: 51, pos: 18, symbol: "1", type: Token.Type.WORD},
        {line: 52, pos: 8, symbol: "i32.add", type: Token.Type.WORD},
        {line: 53, pos: 8, symbol: "local.set", type: Token.Type.WORD},
        {line: 53, pos: 18, symbol: "$1", type: Token.Type.WORD},
        {line: 54, pos: 6, symbol: "end", type: Token.Type.WORD},
        {line: 54, pos: 10, symbol: ";; $block_0", type: Token.Type.COMMENT},
        {line: 55, pos: 6, symbol: "local.get", type: Token.Type.WORD},
        {line: 55, pos: 16, symbol: "$2", type: Token.Type.WORD},
        {line: 56, pos: 6, symbol: "local.set", type: Token.Type.WORD},
        {line: 56, pos: 16, symbol: "$0", type: Token.Type.WORD},
        {line: 57, pos: 6, symbol: "local.get", type: Token.Type.WORD},
        {line: 57, pos: 16, symbol: "$2", type: Token.Type.WORD},
        {line: 58, pos: 6, symbol: "i32.const", type: Token.Type.WORD},
        {line: 58, pos: 16, symbol: "0", type: Token.Type.WORD},
        {line: 59, pos: 6, symbol: "i32.gt_s", type: Token.Type.WORD},
        {line: 60, pos: 6, symbol: "br_if", type: Token.Type.WORD},
        {line: 60, pos: 12, symbol: "$loop", type: Token.Type.WORD},
        {line: 61, pos: 4, symbol: "end", type: Token.Type.WORD},
        {line: 61, pos: 8, symbol: ";; $loop", type: Token.Type.COMMENT},
        {line: 62, pos: 2, symbol: "end", type: Token.Type.WORD},
        {line: 62, pos: 6, symbol: ";; $block", type: Token.Type.COMMENT},
        {line: 63, pos: 2, symbol: "local.get", type: Token.Type.WORD},
        {line: 63, pos: 12, symbol: "$1", type: Token.Type.WORD},
        {line: 64, pos: 2, symbol: ")", type: Token.Type.BRACKET},
        {line: 66, pos: 0, symbol: "(", type: Token.Type.BRACKET},
        {line: 66, pos: 1, symbol: "func", type: Token.Type.WORD},
        {line: 66, pos: 6, symbol: "$_start", type: Token.Type.WORD},
        {line: 66, pos: 14, symbol: "(", type: Token.Type.BRACKET},
        {line: 66, pos: 15, symbol: "type", type: Token.Type.WORD},
        {line: 66, pos: 20, symbol: "$2", type: Token.Type.WORD},
        {line: 66, pos: 22, symbol: ")", type: Token.Type.BRACKET},
        {line: 67, pos: 2, symbol: ")", type: Token.Type.BRACKET},
        {line: 69, pos: 0, symbol: `;;(custom_section "producers"`, type: Token.Type.COMMENT},
        {line: 70, pos: 0, symbol: ";;  (after code)", type: Token.Type.COMMENT},
        {line: 71, pos: 0, symbol: `;;  "\01\0cprocessed-by\01\03ldc\061.20.1")`, type: Token
        .Type.COMMENT},
        {line: 73, pos: 0, symbol: ")", type: Token.Type.BRACKET},
    ];

    const parser = Tokenizer(src);

    import std.stdio;

    {
        auto range = parser[];
        foreach (t; tokens) {
            assert(range.line is t.line);
            assert(range.pos is t.pos);
            assert(range.front.symbol == t.symbol);
            assert(range.front.type is t.type);
            assert(range.front == t);
            assert(!range.empty);
            range.popFront;
        }
        assert(range.empty);
    }

    { // Test ForwardRange
        auto range = parser[];
        // writefln("%s", range.front);
        range.popFront;
        auto saved_range = range.save;
        immutable before_token_1 = range.front;

        // writefln("%s", range.front);
        range.popFront;
        assert(before_token_1 != range.front);
        // writefln("save %s", saved_range.front);
        assert(before_token_1 == saved_range.front);
        saved_range.popFront;
        assert(range.front == saved_range.front);

        //        range.popFront;
    }
}

struct WasmWord {
}

enum WASMKeywords = [
        "module", "type", "memory", "table", "global", "export", "func", "result",
        "param", "local.get", "local.set", "local.tee", "local", "global.get",
        "global.set", "block", "loop", "br", "br_if", "br_table", "end", "return",

        "if", "then", "else", "call", "call_indirect", "unreachable", "nop",

        "drop", "select", "memory.size", "memory.grow",

        // i32
        "i32.const", "i32.load", "i32.load8_s", "i32.load16_s", "i32.load8_u",
        "i32.load16_u", "i32.store", "i32.store8", "i32.store16", "i32.clz",
        "i32.ctz", "i32.popcnt", "i32.add", "i32.sub", "i32.div_s", "i32.div_u",
        "i32.rem_u", "i32.and", "i32.or", "i32.xor", "i32.shr_s", "i32.shr_u",
        "i32.rotl", "i32.rotr",
        // i32 compare
        "i32.eqz", "i32.eq", "i32.ne", "i32.lt_s", "i32.lt_u", "i32.gt_s",
        "i32.gt_u", "i32.le_s", "i32.le_u", "i32.ge_s", "i32.ge_u",
        // i32 comversion
        "i32.wrap_i64", "i32.trunc_f32_s", "i32.trunc_f32_u", "i32.trunc_f64_s",
        "i32.trunc_f64_u", "i32.reinterpret_f32",

        // i64
        "i64.const", "i64.load", "i64.load8_s", "i64.load16_s",
        "i64.load32_s", "i64.load8_u", "i64.load16_u", "i64.load32_u",

        "i64.store", "i64.store8", "i64.store16", "i64.store32", "i64.clz",
        "i64.ctz", "i64.popcnt", "i64.add", "i64.sub", "i64.div_s", "i64.div_u",
        "i64.rem_u", "i64.and", "i64.or", "i64.xor", "i64.shr_s", "i64.shr_u",
        "i64.rotl", "i64.rotr",
        // i64 compare
        "i64.eqz", "i64.eq", "i64.ne", "i64.lt_s", "i64.lt_u", "i64.gt_s",
        "i64.gt_u", "i64.le_s", "i64.le_u", "i64.ge_s", "i64.ge_u",
        // i32 comversion
        "i64.extend_i32_s", "i64.extend_i32_u", "i64.trunc_f32_s",
        "i64.trunc_f32_u", "i64.trunc_f64_s", "i64.trunc_f64_u",
        "i64.reinterpret_f64",

        // f32
        "f32.load", "f32.store", "f32.abs", "f32.neg", "f32.ceil", "f32.floor",
        "f32.trunc", "f32.nearest", "f32.sqrt", "f32.add", "f32.sub", "f32.mul",
        "f32.mul", "f32.min", "f32.max", "f32.copysign",
        // f32 compare
        "f32.eq", "f32.ne", "f32.lt", "f32.gt", "f32.le", "f32.ge",
        // f32 comvert
        "f32.convert_i32_s", "f32.convert_i32_u", "f32.convert_i64_s",
        "f32.convert_i64_u", "f32.demote_f64", "f32.reinterpret_i32",

        // f64
        "f64.load", "f64.store", "f64.abs", "f64.neg", "f64.ceil", "f64.floor",
        "f64.trunc", "f64.nearest", "f64.sqrt", "f64.add", "f64.sub", "f64.mul",
        "f64.mul", "f64.min", "f64.max", "f64.copysign",
        // f64 compare
        "f64.eq", "f64.ne", "f64.lt", "f64.gt", "f64.le", "f64.ge",
        // f64 comvert
        "f64.convert_i32_s", "f64.convert_i32_u", "f64.convert_i64_s",
        "f64.convert_i64_u", "f64.promote_f32", "f64.reinterpret_i64"

    ];
