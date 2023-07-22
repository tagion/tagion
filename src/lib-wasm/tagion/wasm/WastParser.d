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
            check(r.type == TokenType.BEGIN, r);
            scope (exit) {
                check(r.type == TokenType.END, r);
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
                        r.popFront;
                        label = r.token;
                        writefln("Local %s %s", instr.name, label);
                        check(r.type == TokenType.WORD, r);
                        r.popFront;
                        writefln("End Local %s", r.type);
                        break;
                    case GLOBAL:
                        r.popFront;
                        label = r.token;
                        writefln("Global %s %s", instr.name, label);
                        check(r.type == TokenType.WORD, r);
                        r.popFront;
                        writefln("End global %s", r.type);
                        break;
                    case MEMORY:
                        break;
                    case MEMOP:
                        break;
                    case CONST:
                        writefln("Const %s %d", instr.wast, instr.pops);
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
            writefln("parse_section %s", r);
            if (r.type == TokenType.BEGIN) {
                string label;
                string arg;
                r.popFront;
                scope (exit) {
                    check(r.type == TokenType.END, r);
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
                    check(r.type == TokenType.WORD, r);
                    label = r.token;
                    writefln("::Func label %s", label);
                    r.popFront;
                    ParserStage arg_stage;
                    WastTokenizer rewined;
                    do {
                        rewined = r.save;
                        arg_stage = parse_section(r, ParserStage.FUNC);
                        writefln("Args %s", arg_stage);
                    }
                    while (arg_stage == ParserStage.PARAM);
                    //auto result_r=r.save;
                    if (arg_stage != ParserStage.RESULT) {
                        writefln(">Rewind %s %s", r.token, r.type);
                        r = rewined;
                        writefln("<Rewind %s %s", r.token, r.type);

                        //parse_section(r, ParserStage.FUNC);
                    }
                    writefln("Begin function %s %s", label, r.type);
                    parse_instr(r, ParserStage.FUNC_BODY);
                    writefln("End function %s %s:%s ", label, r.token, r.type);
                    return ParserStage.FUNC;
                case "param": // Example (param $y i32)
                    check(stage == ParserStage.FUNC, r);
                    r.popFront;
                    check(r.type == TokenType.WORD, r);
                    label = r.token;
                    r.popFront;
                    check(r.type == TokenType.WORD, r);
                    arg = r.token;
                    r.popFront;
                    writefln("::Param %s %s", label, arg);
                    //parse_section(r, stage);
                    return ParserStage.PARAM;
                case "result":
                    check(stage == ParserStage.FUNC, r);
                    r.popFront;
                    check(r.type == TokenType.WORD, r);
                    arg = r.token;
                    r.popFront;
                    writefln("::Result %s", arg);
                    return ParserStage.RESULT;
                case "export":
                    check(stage == ParserStage.MODULE, r);

                    r.popFront;
                    writefln("export %s", r);
                    check(r.type == TokenType.STRING, r);
                    label = r.token;
                    r.popFront;
                    arg = r.token;
                    writefln("---export %s", r);
                    check(r.type == TokenType.WORD, r);
                    writefln("End export %s %s", label, arg);
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
                    writefln("String %s", r);

                    check(r.type == TokenType.STRING, r);
                    arg = r.token;
                    r.popFront;
                    return ParserStage.ASSERT;
                default:
                    if (r.type == TokenType.COMMENT) {
                        writefln("Comment!!!");
                        r.popFront;
                        return ParserStage.COMMENT;
                    }
                    /*
                    if (stage == ParserStage.FUNC) {
                        r.popFront;
                        writefln("---> FUNC body begin %s", r.type);
                        return parse_instr(r, ParserStage.FUNC);
                    }
                    else {
                */
                    r.popFront;
                    parse_section(r, stage);
                    //  }
                }

                if (r.type != TokenType.END) {
                    writefln("Error %s expected", TokenType.END);
                }
            }
            writefln("End!!");
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
