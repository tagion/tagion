module tagion.vm.wavm.WasmParser;

import std.uni : toUpper;
import std.traits : EnumMembers;
import std.format;

import tagion.utils.LEB128;

//import tagion.Message : message;

struct Token {
    string name;
    uint line;
    uint pos;
    string toText() @safe pure const {
        if ( line is 0 ) {
            return name;
        }
        else {
//            return message("%s:%s:%s",  line, pos, name);
            return format("%s:%s:%s", line, pos, name);
        }
    }
}

@safe
struct Tokenizer {
    immutable(string) source;
    immutable(string) file;
    this(string source, string file=null) {
        this.source=source;
        this.file=file;
    }

    Range opSlice() const {
        return Range(source);
    }

    struct Range {
        immutable(string) source;
        protected {
            size_t _begin_pos;    /// Begin position of a token
            size_t _end_pos;      /// End position of a token
            uint   _line;         /// Line number
            size_t _line_pos;     /// Position of the current line
            uint   _current_line; /// Line number of the current token
            size_t _current_pos;  /// Position of the token in the current line
            bool _eos;            /// Markes end of stream
        }
        this(string source) {
            _line=1;
            this.source=source;
//            trim;
            popFront;
        }

        @property const pure nothrow {
            uint line() {
                return _current_line;
            }

            uint pos() {
                return cast(uint)(_begin_pos-_current_pos);
            }

            immutable(string) front() {
                return source[_begin_pos.._end_pos];
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
                return source[begin..end];
            }

        }


        @property void popFront() {
            _eos = (_end_pos == source.length);
            trim;
            _end_pos=_begin_pos;
            _current_line=_line;
            _current_pos=_line_pos;
            if (_end_pos < source.length) {
                if ((_end_pos+1<source.length) && (source[_end_pos.._end_pos+2] == "(;")) {
                    _end_pos+=2;
                    uint level=1;
                    while (_end_pos+1 < source.length) {
                        const eol=is_newline(source[_end_pos..$]);
                        if ( eol ) {
                            _end_pos+=eol;
                            _line_pos=_end_pos;
                            _line++;
                        }
                        else if (source[_end_pos.._end_pos+2] == ";)") {
                            _end_pos+=2;
                            level--;
                            if (level==0) {
                                break;
                            }
                        }
                        else if (source[_end_pos.._end_pos+2] == "(;") {
                            _end_pos+=2;
                            level++;
                        }
                        else {
                            _end_pos++;
                        }
                    }
                }
                else if ((_end_pos+1<source.length) && (source[_end_pos.._end_pos+2] == ";;")) {
                    _end_pos+=2;
                    while ((_end_pos < source.length) && (!is_newline(source[_end_pos..$]))) {
                        _end_pos++;
                    }
                }
                else if ((source[_end_pos] is '(') || (source[_end_pos] is ')')) {
                    _end_pos++;
                }
                else if (source[_end_pos] is '"' || source[_end_pos] is '\'') {
                    const quote=source[_begin_pos];
                    _end_pos++;
                    bool escape;
                    while (_end_pos < source.length) {
                        const eol=is_newline(source[_end_pos..$]);
                        if (eol) {
                            _end_pos+=eol;
                            _line_pos=_end_pos;
                            _line++;
                        }
                        else {
                            if (!escape) {
                                escape=source[_end_pos] is '\\';
                            }
                            else {
                                escape=false;
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
                    while((_end_pos < source.length) && is_none_white(source[_end_pos]) && (source[_end_pos] !is ')')) {
                        _end_pos++;
                    }
                }
            }
            if (_end_pos is _begin_pos) {
                _eos=true;
            }
        }

        protected void trim() {
            scope size_t eol;
            _begin_pos=_end_pos;
            while (_begin_pos < source.length) {
                if (is_white_space(source[_begin_pos])) {
                    _begin_pos++;
                }
                else if ((eol=is_newline(source[_begin_pos..$])) !is 0) {
                    _begin_pos+=eol;
                    _line_pos=_begin_pos;
                    _line++;
                }
                else {
                    break;
                }
            }
        }
    }

    static bool is_white_space(immutable char c) @safe pure nothrow {
        return ( (c is ' ') || ( c is '\t' ) );
    }

    static bool is_none_white(immutable char c) @safe pure nothrow {
        return  (c !is ' ') && (c !is '\t') && (c !is '\n') && (c !is '\r');
    }

    static size_t is_newline(string str) pure {
        if ( (str.length > 0) && (str[0] == '\n') ) {
            if ( ( str.length > 1) && ( (str[0..2] == "\n\r") || (str[0..2] == "\r\n") ) ) {
                return 2;
            }
            return 1;
        }
        return 0;
    }

}

unittest {
    import std.string : join;
    immutable src=[
        "(module",
        "(type $0 (func (param f64 f64) (result f64)))",
        "(type $1 (func (param i32 i32) (result i32)))",
        "(type $2 (func))",
        "(memory $4  2)",
        "(table $3  1 1 funcref)",
        "(global $5  (mut i32) (i32.const 66560))",
        `(export "memory" (memory $4))`,
        `(export "add" (func $add))`,
        `(export "while_loop" (func $while_loop))`,
        `(export "_start" (func $_start))`,
        "",
        "(func $add (type $0)",
        "  (param $0 f64)",
        "  (param $1 f64)",
        "  (result f64)",
        "  local.get $0",
        "  local.get $1",
        "  f64.add",
        "  )",
        "",
        "(func $while_loop (type $1)",
        "  (param $0 i32)",
        "  (param $1 i32)",
        "  (result i32)",
        "  (local $2 i32)",
        "  block $block",
        "    local.get $0",
        "    i32.const 1",
        "    i32.lt_s",
        "    br_if $block",
        "    loop $loop",
        "      local.get $0",
        "      i32.const -1",
        "      i32.add",
        "      local.set $2",
        "      local.get $0",
        "      local.get $1",
        "      i32.mul",
        "      local.set $0",
        "      i32.const 34",
        "      local.set $1",
        "      block $block_0",
        "        local.get $0",
        "        i32.const 17",
        "        i32.eq",
        "        br_if $block_0",
        "        local.get $0",
        "        i32.const 2",
        "        i32.div_s",
        "        i32.const 1",
        "        i32.add",
        "        local.set $1",
        "      end ;; $block_0",
        "      local.get $2",
        "      local.set $0",
        "      local.get $2",
        "      i32.const 0",
        "      i32.gt_s",
        "      br_if $loop",
        "    end ;; $loop",
        "  end ;; $block",
        "  local.get $1",
        "  )",
        "",
        "(func $_start (type $2)",
        "  )",
        "",
        `;;(custom_section "producers"`,
        ";;  (after code)",
        `;;  "\01\0cprocessed-by\01\03ldc\061.20.1")`,
        "",
        ")"].join("\n")
        ;
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

    struct Token {
        uint line;
        size_t pos;
        string token;
    }


    immutable(Token[]) tokens=
        [
            {line : 1, pos : 0, token : "("},
            {line : 1, pos : 1, token : "module"},
            {line : 2, pos : 0, token : "("},
            {line : 2, pos : 1, token : "type"},
            {line : 2, pos : 6, token : "$0"},
            {line : 2, pos : 9, token : "("},
            {line : 2, pos : 10, token : "func"},
            {line : 2, pos : 15, token : "("},
            {line : 2, pos : 16, token : "param"},
            {line : 2, pos : 22, token : "f64"},
            {line : 2, pos : 26, token : "f64"},
            {line : 2, pos : 29, token : ")"},
            {line : 2, pos : 31, token : "("},
            {line : 2, pos : 32, token : "result"},
            {line : 2, pos : 39, token : "f64"},
            {line : 2, pos : 42, token : ")"},
            {line : 2, pos : 43, token : ")"},
            {line : 2, pos : 44, token : ")"},
            {line : 3, pos : 0, token : "("},
            {line : 3, pos : 1, token : "type"},
            {line : 3, pos : 6, token : "$1"},
            {line : 3, pos : 9, token : "("},
            {line : 3, pos : 10, token : "func"},
            {line : 3, pos : 15, token : "("},
            {line : 3, pos : 16, token : "param"},
            {line : 3, pos : 22, token : "i32"},
            {line : 3, pos : 26, token : "i32"},
            {line : 3, pos : 29, token : ")"},
            {line : 3, pos : 31, token : "("},
            {line : 3, pos : 32, token : "result"},
            {line : 3, pos : 39, token : "i32"},
            {line : 3, pos : 42, token : ")"},
            {line : 3, pos : 43, token : ")"},
            {line : 3, pos : 44, token : ")"},
            {line : 4, pos : 0, token : "("},
            {line : 4, pos : 1, token : "type"},
            {line : 4, pos : 6, token : "$2"},
            {line : 4, pos : 9, token : "("},
            {line : 4, pos : 10, token : "func"},
            {line : 4, pos : 14, token : ")"},
            {line : 4, pos : 15, token : ")"},
            {line : 5, pos : 0, token : "("},
            {line : 5, pos : 1, token : "memory"},
            {line : 5, pos : 8, token : "$4"},
            {line : 5, pos : 12, token : "2"},
            {line : 5, pos : 13, token : ")"},
            {line : 6, pos : 0, token : "("},
            {line : 6, pos : 1, token : "table"},
            {line : 6, pos : 7, token : "$3"},
            {line : 6, pos : 11, token : "1"},
            {line : 6, pos : 13, token : "1"},
            {line : 6, pos : 15, token : "funcref"},
            {line : 6, pos : 22, token : ")"},
            {line : 7, pos : 0, token : "("},
            {line : 7, pos : 1, token : "global"},
            {line : 7, pos : 8, token : "$5"},
            {line : 7, pos : 12, token : "("},
            {line : 7, pos : 13, token : "mut"},
            {line : 7, pos : 17, token : "i32"},
            {line : 7, pos : 20, token : ")"},
            {line : 7, pos : 22, token : "("},
            {line : 7, pos : 23, token : "i32.const"},
            {line : 7, pos : 33, token : "66560"},
            {line : 7, pos : 38, token : ")"},
            {line : 7, pos : 39, token : ")"},
            {line : 8, pos : 0, token : "("},
            {line : 8, pos : 1, token : "export"},
            {line : 8, pos : 8, token : `"memory"`},
            {line : 8, pos : 17, token : "("},
            {line : 8, pos : 18, token : "memory"},
            {line : 8, pos : 25, token : "$4"},
            {line : 8, pos : 27, token : ")"},
            {line : 8, pos : 28, token : ")"},
            {line : 9, pos : 0, token : "("},
            {line : 9, pos : 1, token : "export"},
            {line : 9, pos : 8, token : `"add"`},
            {line : 9, pos : 14, token : "("},
            {line : 9, pos : 15, token : "func"},
            {line : 9, pos : 20, token : "$add"},
            {line : 9, pos : 24, token : ")"},
            {line : 9, pos : 25, token : ")"},
            {line : 10, pos : 0, token : "("},
            {line : 10, pos : 1, token : "export"},
            {line : 10, pos : 8, token :`"while_loop"`},
            {line : 10, pos : 21, token : "("},
            {line : 10, pos : 22, token : "func"},
            {line : 10, pos : 27, token : "$while_loop"},
            {line : 10, pos : 38, token : ")"},
            {line : 10, pos : 39, token : ")"},
            {line : 11, pos : 0, token : "("},
            {line : 11, pos : 1, token : "export"},
            {line : 11, pos : 8, token : `"_start"`},
            {line : 11, pos : 17, token : "("},
            {line : 11, pos : 18, token : "func"},
            {line : 11, pos : 23, token : "$_start"},
            {line : 11, pos : 30, token : ")"},
            {line : 11, pos : 31, token : ")"},
            {line : 13, pos : 0, token : "("},
            {line : 13, pos : 1, token : "func"},
            {line : 13, pos : 6, token : "$add"},
            {line : 13, pos : 11, token : "("},
            {line : 13, pos : 12, token : "type"},
            {line : 13, pos : 17, token : "$0"},
            {line : 13, pos : 19, token : ")"},
            {line : 14, pos : 2, token : "("},
            {line : 14, pos : 3, token : "param"},
            {line : 14, pos : 9, token : "$0"},
            {line : 14, pos : 12, token : "f64"},
            {line : 14, pos : 15, token : ")"},
            {line : 15, pos : 2, token : "("},
            {line : 15, pos : 3, token : "param"},
            {line : 15, pos : 9, token : "$1"},
            {line : 15, pos : 12, token : "f64"},
            {line : 15, pos : 15, token : ")"},
            {line : 16, pos : 2, token : "("},
            {line : 16, pos : 3, token : "result"},
            {line : 16, pos : 10, token : "f64"},
            {line : 16, pos : 13, token : ")"},
            {line : 17, pos : 2, token : "local.get"},
            {line : 17, pos : 12, token : "$0"},
            {line : 18, pos : 2, token : "local.get"},
            {line : 18, pos : 12, token : "$1"},
            {line : 19, pos : 2, token : "f64.add"},
            {line : 20, pos : 2, token : ")"},
            {line : 22, pos : 0, token : "("},
            {line : 22, pos : 1, token : "func"},
            {line : 22, pos : 6, token : "$while_loop"},
            {line : 22, pos : 18, token : "("},
            {line : 22, pos : 19, token : "type"},
            {line : 22, pos : 24, token : "$1"},
            {line : 22, pos : 26, token : ")"},
            {line : 23, pos : 2, token : "("},
            {line : 23, pos : 3, token : "param"},
            {line : 23, pos : 9, token : "$0"},
            {line : 23, pos : 12, token : "i32"},
            {line : 23, pos : 15, token : ")"},
            {line : 24, pos : 2, token : "("},
            {line : 24, pos : 3, token : "param"},
            {line : 24, pos : 9, token : "$1"},
            {line : 24, pos : 12, token : "i32"},
            {line : 24, pos : 15, token : ")"},
            {line : 25, pos : 2, token : "("},
            {line : 25, pos : 3, token : "result"},
            {line : 25, pos : 10, token : "i32"},
            {line : 25, pos : 13, token : ")"},
            {line : 26, pos : 2, token : "("},
            {line : 26, pos : 3, token : "local"},
            {line : 26, pos : 9, token : "$2"},
            {line : 26, pos : 12, token : "i32"},
            {line : 26, pos : 15, token : ")"},
            {line : 27, pos : 2, token : "block"},
            {line : 27, pos : 8, token : "$block"},
            {line : 28, pos : 4, token : "local.get"},
            {line : 28, pos : 14, token : "$0"},
            {line : 29, pos : 4, token : "i32.const"},
            {line : 29, pos : 14, token : "1"},
            {line : 30, pos : 4, token : "i32.lt_s"},
            {line : 31, pos : 4, token : "br_if"},
            {line : 31, pos : 10, token : "$block"},
            {line : 32, pos : 4, token : "loop"},
            {line : 32, pos : 9, token : "$loop"},
            {line : 33, pos : 6, token : "local.get"},
            {line : 33, pos : 16, token : "$0"},
            {line : 34, pos : 6, token : "i32.const"},
            {line : 34, pos : 16, token : "-1"},
            {line : 35, pos : 6, token : "i32.add"},
            {line : 36, pos : 6, token : "local.set"},
            {line : 36, pos : 16, token : "$2"},
            {line : 37, pos : 6, token : "local.get"},
            {line : 37, pos : 16, token : "$0"},
            {line : 38, pos : 6, token : "local.get"},
            {line : 38, pos : 16, token : "$1"},
            {line : 39, pos : 6, token : "i32.mul"},
            {line : 40, pos : 6, token : "local.set"},
            {line : 40, pos : 16, token : "$0"},
            {line : 41, pos : 6, token : "i32.const"},
            {line : 41, pos : 16, token : "34"},
            {line : 42, pos : 6, token : "local.set"},
            {line : 42, pos : 16, token : "$1"},
            {line : 43, pos : 6, token : "block"},
            {line : 43, pos : 12, token : "$block_0"},
            {line : 44, pos : 8, token : "local.get"},
            {line : 44, pos : 18, token : "$0"},
            {line : 45, pos : 8, token : "i32.const"},
            {line : 45, pos : 18, token : "17"},
            {line : 46, pos : 8, token : "i32.eq"},
            {line : 47, pos : 8, token : "br_if"},
            {line : 47, pos : 14, token : "$block_0"},
            {line : 48, pos : 8, token : "local.get"},
            {line : 48, pos : 18, token : "$0"},
            {line : 49, pos : 8, token : "i32.const"},
            {line : 49, pos : 18, token : "2"},
            {line : 50, pos : 8, token : "i32.div_s"},
            {line : 51, pos : 8, token : "i32.const"},
            {line : 51, pos : 18, token : "1"},
            {line : 52, pos : 8, token : "i32.add"},
            {line : 53, pos : 8, token : "local.set"},
            {line : 53, pos : 18, token : "$1"},
            {line : 54, pos : 6, token : "end"},
            {line : 54, pos : 10, token : ";; $block_0"},
            {line : 55, pos : 6, token : "local.get"},
            {line : 55, pos : 16, token : "$2"},
            {line : 56, pos : 6, token : "local.set"},
            {line : 56, pos : 16, token : "$0"},
            {line : 57, pos : 6, token : "local.get"},
            {line : 57, pos : 16, token : "$2"},
            {line : 58, pos : 6, token : "i32.const"},
            {line : 58, pos : 16, token : "0"},
            {line : 59, pos : 6, token : "i32.gt_s"},
            {line : 60, pos : 6, token : "br_if"},
            {line : 60, pos : 12, token : "$loop"},
            {line : 61, pos : 4, token : "end"},
            {line : 61, pos : 8, token : ";; $loop"},
            {line : 62, pos : 2, token : "end"},
            {line : 62, pos : 6, token : ";; $block"},
            {line : 63, pos : 2, token : "local.get"},
            {line : 63, pos : 12, token : "$1"},
            {line : 64, pos : 2, token : ")"},
            {line : 66, pos : 0, token : "("},
            {line : 66, pos : 1, token : "func"},
            {line : 66, pos : 6, token : "$_start"},
            {line : 66, pos : 14, token : "("},
            {line : 66, pos : 15, token : "type"},
            {line : 66, pos : 20, token : "$2"},
            {line : 66, pos : 22, token : ")"},
            {line : 67, pos : 2, token : ")"},
            {line : 69, pos : 0, token : `;;(custom_section "producers"`},
            {line : 70, pos : 0, token : ";;  (after code)"},
            {line : 71, pos : 0, token : `;;  "\01\0cprocessed-by\01\03ldc\061.20.1")`},
            {line : 73, pos : 0, token : ")"},
            ];

    const parser=Tokenizer(src);
//    uint count;
    auto range_1=parser[];

    import std.stdio;
//     while (!range_1.empty) {
// //    foreach(t; parser[]) {
// //        const x=t.token;
//         writefln("{line : %d, pos : %d, token : \"%s\"},", range_1.line, range_1.pos, range_1.front);
//         range_1.popFront;
//     }
    auto range=parser[];
    foreach(t; tokens) {
        assert(range.line is t.line);
        assert(range.pos is t.pos);
        assert(range.front == t.token);
        assert(!range.empty);
        range.popFront;
    }
    assert(range.empty);
}

struct WasmWord {
}
enum WASMKeywords = [
    "module",
    "type",
    "memory",
    "table",
    "global",
    "export",
    "func",
    "result",
    "param",

    "local.get",
    "local.set",
    "local.tee",
    "local",

    "global.get",
    "global.set",

    "block",
    "loop",
    "br",
    "br_if",
    "br_table",
    "end",
    "return",

    "if",
    "then",
    "else",

    "call",
    "call_indirect",


    "unreachable",
    "nop",

    "drop",
    "select",

    "memory.size",
    "memory.grow",

    // i32
    "i32.const",
    "i32.load",
    "i32.load8_s",
    "i32.load16_s",
    "i32.load8_u",
    "i32.load16_u",

    "i32.store",
    "i32.store8",
    "i32.store16",

    "i32.clz",
    "i32.ctz",
    "i32.popcnt",
    "i32.add",
    "i32.sub",
    "i32.div_s",
    "i32.div_u",
    "i32.rem_u",
    "i32.and",
    "i32.or",
    "i32.xor",
    "i32.shr_s",
    "i32.shr_u",
    "i32.rotl",
    "i32.rotr",
    // i32 compare
    "i32.eqz",
    "i32.eq",
    "i32.ne",
    "i32.lt_s",
    "i32.lt_u",
    "i32.gt_s",
    "i32.gt_u",
    "i32.le_s",
    "i32.le_u",
    "i32.ge_s",
    "i32.ge_u",
    // i32 comversion
    "i32.wrap_i64",
    "i32.trunc_f32_s",
    "i32.trunc_f32_u",
    "i32.trunc_f64_s",
    "i32.trunc_f64_u",
    "i32.reinterpret_f32",


    // i64
    "i64.const",
    "i64.load",
    "i64.load8_s",
    "i64.load16_s",
    "i64.load32_s",
    "i64.load8_u",
    "i64.load16_u",
    "i64.load32_u",

    "i64.store",
    "i64.store8",
    "i64.store16",
    "i64.store32",

    "i64.clz",
    "i64.ctz",
    "i64.popcnt",
    "i64.add",
    "i64.sub",
    "i64.div_s",
    "i64.div_u",
    "i64.rem_u",
    "i64.and",
    "i64.or",
    "i64.xor",
    "i64.shr_s",
    "i64.shr_u",
    "i64.rotl",
    "i64.rotr",
    // i64 compare
    "i64.eqz",
    "i64.eq",
    "i64.ne",
    "i64.lt_s",
    "i64.lt_u",
    "i64.gt_s",
    "i64.gt_u",
    "i64.le_s",
    "i64.le_u",
    "i64.ge_s",
    "i64.ge_u",
    // i32 comversion
    "i64.extend_i32_s",
    "i64.extend_i32_u",
    "i64.trunc_f32_s",
    "i64.trunc_f32_u",
    "i64.trunc_f64_s",
    "i64.trunc_f64_u",
    "i64.reinterpret_f64",

    // f32
    "f32.load",
    "f32.store",

    "f32.abs",
    "f32.neg",
    "f32.ceil",
    "f32.floor",
    "f32.trunc",
    "f32.nearest",
    "f32.sqrt",
    "f32.add",
    "f32.sub",
    "f32.mul",
    "f32.mul",
    "f32.min",
    "f32.max",
    "f32.copysign",
    // f32 compare
    "f32.eq",
    "f32.ne",
    "f32.lt",
    "f32.gt",
    "f32.le",
    "f32.ge",
    // f32 comvert
    "f32.convert_i32_s",
    "f32.convert_i32_u",
    "f32.convert_i64_s",
    "f32.convert_i64_u",
    "f32.demote_f64",
    "f32.reinterpret_i32",

    // f64
    "f64.load",
    "f64.store",

    "f64.abs",
    "f64.neg",
    "f64.ceil",
    "f64.floor",
    "f64.trunc",
    "f64.nearest",
    "f64.sqrt",
    "f64.add",
    "f64.sub",
    "f64.mul",
    "f64.mul",
    "f64.min",
    "f64.max",
    "f64.copysign",
    // f64 compare
    "f64.eq",
    "f64.ne",
    "f64.lt",
    "f64.gt",
    "f64.le",
    "f64.ge",
    // f64 comvert
    "f64.convert_i32_s",
    "f64.convert_i32_u",
    "f64.convert_i64_s",
    "f64.convert_i64_u",
    "f64.promote_f32",
    "f64.reinterpret_i64"

    ];

// enum WAVMKeyword {
//     NONE,
//     MODULE,
//     TYPE,
//     MEMORY,
//     TABLE,
//     GLOBAL,
//     EXPORT,
//     FUNC,
//     PARAM,
//     RESULT,

//     LOCAL_GET,
//     LOCAL_SET,
//     LOCAL,
//     BLOCK,

//     // I32
//     I32_CONST,
//     I32
//     I32_CLZ,
//     I32_CTZ,
//     I32_POPCNT,
//     I32_ADD,
//     I32_SUB,
//     I32_DIV_S,
//     I32_DIV_U,
//     I32_REM_U,
//     I32_AND,
//     I32_OR,
//     I32_XOR,
//     I32_SHR_S,
//     I32_SHR_U,
//     I32_ROTL,
//     I32_ROTR,


//     AND
//     F64_ADD,





//     DO,
//     LOOP,
//     ADDLOOP,
//     BEGIN,
//     REPEAT,
//     UNTIL,
//     WHILE,
//     LEAVE,
//     AGAIN,
//     EXIT,
//     IF,
//     ELSE,
//     ENDIF,
//     THEN,
//     FUNC,
//     ENDFUNC,

//     I,
//     GET,
//     COMMENT,
//     // Regex tokens
//     VAR,
//     NUMBER,
//     HEX,
//     WORD,
//     TEXT,
//     PUT,
// }

// enum keywordMap = [
//     ScriptKeyword.DO            : ScriptKeyword.DO.stringof.tolower,
//     ScriptKeyword.LOOP          : ScriptKeyword.LOOP.stringof,
//     ScriptKeyword.ADDLOOP       : "+LOOP",
//     ScriptKeyword.BEGIN         : ScriptKeyword.BEGIN.stringof,
//     ScriptKeyword.UNTIL         : ScriptKeyword.UNTIL.stringof,
//     ScriptKeyword.WHILE         : ScriptKeyword.WHILE.stringof,
//     ScriptKeyword.REPEAT        : ScriptKeyword.REPEAT.stringof,
//     ScriptKeyword.LEAVE         : ScriptKeyword.LEAVE.stringof,
//     ScriptKeyword.AGAIN         : ScriptKeyword.AGAIN.stringof,
//     ScriptKeyword.EXIT          : ScriptKeyword.EXIT.stringof,
//     ScriptKeyword.IF            : ScriptKeyword.IF.stringof,
//     ScriptKeyword.ELSE          : ScriptKeyword.ELSE.stringof,
//     ScriptKeyword.ENDIF         : ScriptKeyword.ENDIF.stringof,
//     ScriptKeyword.THEN          : ScriptKeyword.THEN.stringof,
//     ScriptKeyword.LOOP          : ScriptKeyword.LOOP.stringof,
//     ScriptKeyword.I             : ScriptKeyword.I.stringof,
//     ScriptKeyword.BEGIN         : ScriptKeyword.BEGIN.stringof,

//     ScriptKeyword.FUNC          : ":",
//     ScriptKeyword.ENDFUNC       : ";",
//     ScriptKeyword.GET           : "@",
//     ];


// static ScriptKeyword[string] generateLabelMap(const(string[ScriptKeyword]) typemap) {
//     ScriptKeyword[string] result;
//     foreach(e, label; typemap) {
//         if ( label.length !is 0 ){
//             result[label]=e;
//         }
//     }
//     return result;
// }

// unittest {
//     static foreach(E; EnumMembers!ScriptKeyword) {
//         with(ScriptKeyword) {
//             switch(E) {
//             case NONE, NUMBER, HEX, WORD, TEXT, VAR, PUT, COMMENT:
//                 break;
//             default:
//                 import std.format;
//                 assert(E in keywordMap, format("TypeMap %s is not defined", E));
//             }
//         }
//     }
// }

// protected enum _scripttype =[
//     "NONE",
//     "NUM",
//     "I32",
//     "U32",
//     "I64",
//     "U64",
//     "STRING",
//     "DOC",
//     "HIBON"
//     ];

// private import tagion.Base : EnumText;

// mixin(EnumText!("ScriptType", _scripttype));



@safe
static struct Lexer {
    // protected enum ctLabelMap=generateLabelMap(keywordMap);
    import std.regex;
    static Regex!char regex_number() {
        enum _regex_number = regex("^[-+]?[0-9][0-9_]*$");
        return _regex_number;
    }

    static Regex!char regex_word() {
        enum _regex_word   = regex(`^[^"]+$`);
        return _regex_word;
    }

    static Regex!char regex_hex() {
        enum _regex_hex    = regex("^[-+]?0[xX][0-9a-fA-F_][0-9a-fA-F_]*$");
        return _regex_hex;
    }

    static Regex!char regex_text() {
        enum _regex_text   = regex(`^"[^"]*"$`);
        return _regex_text;
    }

    static Regex!char regex_put() {
        enum _regex_put    = regex(r"^[+-/\*><%\^\&\|]*!@?$");
        return _regex_put;
    }

    static Regex!char regex_comment() {
        enum _regeax_comment = regex(r"^\([^\)]+\)$");
        return _regeax_comment;
    }
    static Regex!char regex_bound() {
        enum _regex_bound  = regex(r"^\w+(\[(0x[0-9a-f][0-9a-f_]*|\d+)\.\.(0x[0-9a-f][0-9a-f_]*|\d+)\])?$");
        return _regex_bound;
    }

    static Regex!char regex_reserved_var() {
        enum _regex_reserved_var = regex(r"^(I|TO)\d{0,2}$");
        return _regex_reserved_var;
    }

    version(none)
    static ScriptType getScriptType(string word) {
        static foreach(TYPE; EnumMembers!ScriptType) {
            static if (TYPE is ScriptType.NUM) {
                if ( (word.length >= TYPE.length) &&
                    (word[0..TYPE.length] == TYPE) &&
                    (word.match(regex_bound)) ) {
                    return TYPE;
                }
            }
            else if (word == TYPE) {
                return TYPE;
            }
        }
        return ScriptType.NONE;
    }

    version(none)
    static ScriptKeyword get(string word) {
        ScriptKeyword result;
        with(ScriptKeyword) {
            result=ctLabelMap.get(word, NONE);
            if ( result is NONE ) {
                if ( word.match(regex_number) ) {
                    result=NUMBER;
                }
                else if ( word.match(regex_hex) ) {
                    result=HEX;
                }
                else if ( word.match(regex_text) ) {
                    result=TEXT;
                }
                else if ( word.match(regex_put) ) {
                    result=PUT;
                }
                else if ( word.match(regex_comment) ) {
                    result=COMMENT;
                }
                else if ( Lexer.getScriptType(word) !is ScriptType.NONE ) {
                    result=VAR;
                }
                else if ( word.match(regex_word) ) {
                    result=WORD;
                }
            }
        }
        return result;
    }

    version(none)
    unittest {
        with(ScriptKeyword) {
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
        foreach(c; str) {
            if ((c<=SPACE) || (c>=DEL) || (c is QUATE) ||
                (c is DOUBLE_QUATE) || (c is BACK_QUATE) ||
                (c is LOCAL_SEPARATOR)) {
                return false;
            }
        }
        return true;
    }

    version(none)
    static bool isDeclaration(ScriptKeyword type) pure nothrow{
        with(ScriptKeyword) {
            switch(type) {
            case VAR:
                return true;
            default:
                return false;
            }
        }
        assert(0);
    }
}
