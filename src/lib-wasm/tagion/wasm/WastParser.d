module tagion.wasm.WastParser;

import tagion.wasm.WastTokenizer;
import tagion.wasm.WasmWriter;
import tagion.wasm.WasmBase;
import tagion.basic.Debug;
import std.stdio;

import std.traits;

@safe
struct WastParser {
    WasmWriter writer;
    alias WasmSection = WasmWriter.WasmSection;
    this(WasmWriter writer) @nogc pure nothrow {
        this.writer = writer;
    }

    alias GlobalDesc = WasmSection.ImportType.ImportDesc.GlobalDesc;
    alias Global = WasmSection.Global;
    alias Type = WasmSection.Type;
    alias Function = WasmSection.Function;
    alias Code = WasmSection.Code;
    alias GlobalType = WasmSection.GlobalType;
    alias FuncType = WasmSection.FuncType;
    alias TypeIndex = WasmSection.TypeIndex;
    alias CodeType = WasmSection.CodeType;
    alias ExportType = WasmSection.ExportType;

    enum ParserStage {
        BASE,
        COMMENT,
        MODULE,
        FUNC,
        PARAM,
        RESULT,
        FUNC_BODY,
        CODE,
        END_FUNC,
        EXPORT,
        MEMORY,
        ASSERT,
        EXPECTED,
        END,
    }

    void parse(ref WastTokenizer tokenizer) {
        void check(const bool flag, ref const(WastTokenizer) r, string file = __FILE__, const size_t line = __LINE__) {
            if (!flag) {
                writefln("Error: %s:%s:%d:%d", r.token, r.type, r.line, r.line_pos);
                writefln("%s:%d", file, line);
                //   assert(0, "Check error");
            }
        }

        ParserStage parse_instr(ref WastTokenizer r, const ParserStage stage) {
            writefln("Parse instr %s %s", r.token, r.type);
            if (r.type == TokenType.COMMENT) {
                r.popFront;
                return parse_instr(r, stage);
            }
            check(r.type == TokenType.BEGIN, r);
            scope (exit) {
                check(r.type == TokenType.END, r);
                writefln("<%s %s", r.type, r.token);
                r.popFront;
            }
            r.popFront;
            writefln("IR %s:%s", r.token, r.type);
            check(r.type == TokenType.WORD, r);
            const instr = instrWastLookup.get(r.token, Instr.init);
            writefln("Instr %s", instr);
            string label;
            if (instr !is Instr.init) {
                with (IRType) {
                    final switch (instr.irtype) {
                    case CODE:
                        writefln("code %s %s", instr.wast, instr.pops);
                        r.popFront;
                        foreach (i; 0 .. instr.pops) {
                            writefln("\targ %d '%s'", i, r.token);
                            parse_instr(r, ParserStage.CODE);
                        }
                        writefln("end code %s %s:%s %d:%d", instr.wast, r.token, r.type, r.line, r.line_pos);
                        break;
                    case BLOCK:
                        break;
                    case BRANCH:
                        r.popFront;
                        foreach (i; 0 .. instr.pops) {
                            parse_instr(r, ParserStage.CODE);
                        }
                        break;
                    case BRANCH_TABLE:
                        break;
                    case CALL:
                        r.popFront;
                        label = r.token;
                        r.popFront;
                        while (r.type == TokenType.BEGIN) {
                            parse_instr(r, ParserStage.CODE);
                            writefln("Arg--%s", r);
                        }

                        writefln("End call %s", r);
                        break;
                    case CALL_INDIRECT:
                        break;
                    case LOCAL:
                        writefln("LOCAL %s", r);
                        r.popFront;
                        label = r.token;
                        writefln("LOCAL arg %s", r);
                        check(r.type == TokenType.WORD, r);
                        r.popFront;
                        break;
                    case GLOBAL:
                        r.popFront;
                        label = r.token;
                        check(r.type == TokenType.WORD, r);
                        r.popFront;
                        break;
                    case MEMORY:
                        writefln("MEMORY %s", r);
                        r.popFront;
                        foreach (i; 0 .. instr.pops) {
                            parse_instr(r, ParserStage.CODE);
                        }
                        break;
                    case MEMOP:
                        break;
                    case CONST:
                        r.popFront;
                        check(r.type == TokenType.WORD, r);
                        label = r.token;
                        r.popFront;
                        break;
                    case END:
                        break;
                    case PREFIX:
                    }
                }

            }
            else {
                check(false, r);
            }

            return stage;
        }

        ParserStage parse_section(ref WastTokenizer r, const ParserStage stage) {
            if (r.type == TokenType.COMMENT) {
                r.popFront;
                return parse_section(r, stage);
            }
            if (r.type == TokenType.BEGIN) {
                string label;
                string arg;
                r.popFront;
                bool not_ended;
                scope (exit) {
                    check(r.type == TokenType.END || not_ended, r);
                    r.popFront;
                }
                writefln("Token %s %s", r.token, r.type);
                switch (r.token) {
                case "module":
                    check(stage < ParserStage.MODULE, r);
                    r.popFront;
                    do {
                        parse_section(r, ParserStage.MODULE);

                    }
                    while (r.type != TokenType.END && !r.empty);
                    return ParserStage.MODULE;
                case "func": // Example (func $name (param ...) (result i32) )
                    check(stage < ParserStage.FUNC, r);
                    r.popFront;
                    if (r.type == TokenType.WORD) {
                        // Function with label
                        label = r.token;
                        writefln("::Func label %s", label);
                        r.popFront;
                    }
                    ParserStage arg_stage;
                    WastTokenizer rewined;
                    do {
                        rewined = r.save;
                        arg_stage = parse_section(r, ParserStage.FUNC);
                        writefln("Args %s", arg_stage);
                    }
                    while (arg_stage == ParserStage.PARAM);
                    //auto result_r=r.save;
                    writefln("Before rewind %s", arg_stage);
                    if (arg_stage != ParserStage.RESULT) {
                        r = rewined;
                    }

                    do {
                        const ret = parse_instr(r, ParserStage.FUNC_BODY);
                        check(ret == ParserStage.FUNC_BODY, r);
                    }
                    while (r.type != TokenType.END);
                    return ParserStage.FUNC;
                case "param": // Example (param $y i32)
                    check(stage == ParserStage.FUNC, r);
                    r.popFront;
                    check(r.type == TokenType.WORD, r);
                    if (r.token.getType is Types.EMPTY) {
                        label = r.token;
                        r.popFront;

                        check(r.type == TokenType.WORD, r);
                    }
                    arg = r.token;
                    r.popFront;
                    return ParserStage.PARAM;
                case "result":
                    check(stage == ParserStage.FUNC, r);
                    r.popFront;
                    check(r.type == TokenType.WORD, r);
                    arg = r.token;
                    r.popFront;
                    return ParserStage.RESULT;
                case "memory":
                    check(stage == ParserStage.MODULE, r);
                    r.popFront;
                    check(r.type == TokenType.WORD, r);
                    label = r.token;

                    r.popFront;
                    if (r.type == TokenType.WORD) {
                        arg = r.token;
                        r.popFront;
                    }
                    return ParserStage.MEMORY;
                case "export":
                    check(stage == ParserStage.MODULE, r);

                    r.popFront;
                    check(r.type == TokenType.STRING, r);
                    label = r.token;
                    r.popFront;
                    arg = r.token;
                    check(r.type == TokenType.WORD, r);
                    r.popFront;
                    return ParserStage.EXPORT;
                case "assert_return":
                    check(stage == ParserStage.BASE, r);
                    label = r.token;
                    r.popFront;

                    // Invoke call
                    parse_instr(r, ParserStage.ASSERT);
                    parse_instr(r, ParserStage.EXPECTED);
                    return ParserStage.ASSERT;
                case "assert_trap":
                    check(stage == ParserStage.BASE, r);
                    label = r.token;
                    r.popFront;
                    // Invoke call
                    parse_instr(r, ParserStage.ASSERT);

                    check(r.type == TokenType.STRING, r);
                    arg = r.token;
                    r.popFront;
                    return ParserStage.ASSERT;
                case "assert_return_nan":
                    check(stage == ParserStage.BASE, r);
                    label = r.token;
                    r.popFront;
                    // Invoke call
                    parse_instr(r, ParserStage.ASSERT);

                    return ParserStage.ASSERT;
                default:
                    if (r.type == TokenType.COMMENT) {
                        r.popFront;
                        return ParserStage.COMMENT;
                    }
                    not_ended = true;
                    writefln("DEFAULT %s", r);
                    return stage;
                }
            }
            if (r.type == TokenType.COMMENT) {
                r.popFront;
            }
            return ParserStage.END;
        }

        while (parse_section(tokenizer, ParserStage.BASE) !is ParserStage.END) {
            write("* ");
            //empty    
        }

    }

}

@safe
unittest {
    import tagion.wasm.WastTokenizer : wast_text;

    auto tokenizer = WastTokenizer(wast_text);
    auto writer = new WasmWriter;
    auto wast_parser = WastParser(writer);
    wast_parser.parse(tokenizer);
    tokenizer.popFront;
    writefln("%s:%s", tokenizer.token, tokenizer.type);
    tokenizer.popFront;
    writefln("%s:%s", tokenizer.token, tokenizer.type);
}
