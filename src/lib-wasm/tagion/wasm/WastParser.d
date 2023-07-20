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
        NONE,
        COMMENT,
        MODULE,
        FUNC,
        PARAM,
        RESULT,
        CODE,
        END_FUNC,
        END,
    }

    void parse(ref WastTokenizer tokenizer) {
        void check(const bool flag, ref const(WastTokenizer) r) {
            if (!flag) {
                writefln("Error: %s:%s:%d:%d", r.token, r.type, r.line, r.line_pos);
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
            check(r.type == TokenType.WORD, r);
            const instr = _instrLookupTable.get(r.token, Instr.init);
            string label;
            if (instr !is Instr.init) {
                with (IRType) {
                    final switch (instr.irtype) {
                    case CODE:
                        writefln("code %s", instr.name);
                        parse_instr(r, ParserStage.CODE);
                        break;
                    case BLOCK:
                        break;
                    case BRANCH:
                        break;
                    case BRANCH_TABLE:
                        break;
                    case CALL:
                        break;
                    case CALL_INDIRECT:
                        break;
                    case LOCAL:
                        r.popFront;
                        label = r.token;
                        writefln("Local %s %s", instr.name, label);
                        check(r.type == TokenType.WORD, r);

                        break;
                    case GLOBAL:
                        r.popFront;
                        label = r.token;
                        writefln("Global %s %s", instr.name, label);
                        check(r.type == TokenType.WORD, r);

                        break;
                    case MEMORY:
                        break;
                    case MEMOP:
                        break;
                    case CONST:
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

            return ParserStage.END_FUNC;
        }

        ParserStage parse_section(ref WastTokenizer r, const ParserStage stage) {
            writefln("parse_section %s", r.token);
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
                    parse_section(r, ParserStage.MODULE);
                    return ParserStage.MODULE;
                case "func": // Example (func $name (param ...) (result i32) )
                    check(stage < ParserStage.FUNC, r);
                    r.popFront;
                    check(r.type == TokenType.WORD, r);
                    label = r.token;
                    writefln("::Func label %s", label);
                    r.popFront;
                    ParserStage arg_stage;
                    do {
                        arg_stage = parse_section(r, ParserStage.FUNC);
                        writefln("Args %s", arg_stage);
                    }
                    while (arg_stage == ParserStage.PARAM);
                    //auto result_r=r.save;
                    if (arg_stage == ParserStage.RESULT) {
                        parse_section(r, ParserStage.FUNC);
                    }
                    writefln("End function %s %s", label, r.type);
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
                default:
                    if (r.type == TokenType.COMMENT) {
                        writefln("Comment!!!");
                        r.popFront;
                        return ParserStage.COMMENT;
                    }
                    if (stage == ParserStage.FUNC) {
                        r.popFront;
                        writefln("---> FUNC body begin %s", r.type);
                        return parse_instr(r, ParserStage.FUNC);
                    }
                    else {
                        r.popFront;
                        parse_section(r, stage);
                    }
                }

                if (r.type != TokenType.END) {
                    writefln("Error %s expected", TokenType.END);
                }
            }
            writefln("End!!");
            return ParserStage.END;
        }

        while (parse_section(tokenizer, ParserStage.init) !is ParserStage.END) {
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
