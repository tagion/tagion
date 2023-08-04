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
        ASSERT,
        MODULE,
        TYPE,
        FUNC,
        PARAM,
        RESULT,
        FUNC_BODY,
        CODE,
        END_FUNC,
        EXPORT,
        IMPORT,
        MEMORY,
        EXPECTED,
        END,
        UNDEFINED,
    }

    private ParserStage parseInstr(ref WastTokenizer r, const ParserStage stage) {
        version (none)
            if (r.type == TokenType.COMMENT) {
                r.nextToken;
                return parseInstr(r, stage);
            }
        r.check(r.type == TokenType.BEGIN);
        scope (exit) {
            r.check(r.type == TokenType.END);
            r.nextToken;
        }
        r.nextToken;
        r.check(r.type == TokenType.WORD);
        const instr = instrWastLookup.get(r.token, Instr.init);
        string label;
        if (instr !is Instr.init) {
            with (IRType) {
                final switch (instr.irtype) {
                case CODE:
                    r.nextToken;
                    foreach (i; 0 .. instr.pops) {
                        parseInstr(r, ParserStage.CODE);
                    }
                    break;
                case BLOCK:
                    string arg;
                    r.nextToken;
                    if (r.type == TokenType.WORD) {
                        //r.check(r.type == TokenType.WORD);
                        label = r.token;
                        r.nextToken;
                    }
                    if (r.type == TokenType.WORD) {
                        arg = r.token;
                        r.nextToken;
                    }
                    while (r.type == TokenType.BEGIN) {
                        parseInstr(r, ParserStage.CODE);
                    }
                    return stage;
                case BRANCH:
                    r.nextToken;
                    if (r.type == TokenType.WORD) {
                        label = r.token;
                        r.nextToken;
                    }
                    while (r.type == TokenType.BEGIN) {
                        //foreach (i; 0 .. instr.pops) {
                        parseInstr(r, ParserStage.CODE);
                    }
                    break;
                case BRANCH_IF:
                    r.nextToken;
                    parseInstr(r, ParserStage.CODE);
                    r.check(r.type == TokenType.WORD);
                    label = r.token;
                    r.nextToken;
                    if (r.type == TokenType.BEGIN) {
                        parseInstr(r, ParserStage.CODE);
                    }
                    break;
                case BRANCH_TABLE:
                    break;
                case CALL:
                    r.nextToken;
                    label = r.token;
                    r.nextToken;
                    while (r.type == TokenType.BEGIN) {
                        parseInstr(r, ParserStage.CODE);
                    }

                    break;
                case CALL_INDIRECT:
                    break;
                case LOCAL:
                    string arg;
                    r.nextToken;
                    label = r.token;
                    r.check(r.type == TokenType.WORD);
                    r.nextToken;
                    if (r.type == TokenType.WORD) {
                        arg = r.token;
                        r.nextToken;
                    }
                    else {
                        foreach (i; 0 .. instr.pops) {
                            parseInstr(r, ParserStage.CODE);
                        }
                    }
                    break;
                case GLOBAL:
                    r.nextToken;
                    label = r.token;
                    r.check(r.type == TokenType.WORD);
                    r.nextToken;
                    break;
                case MEMORY:

                    r.nextToken;
                    for (uint i = 0; (i < 2) && (r.type == TokenType.WORD); i++) {
                        label = r.token; // Fix this later
                        r.nextToken;
                    }
                    foreach (i; 0 .. instr.pops) {
                        parseInstr(r, ParserStage.CODE);
                    }
                    break;
                case MEMOP:
                    r.nextToken;
                    foreach (i; 0 .. instr.pops) {
                        parseInstr(r, ParserStage.CODE);
                    }
                    break;
                case CONST:
                    r.nextToken;
                    r.check(r.type == TokenType.WORD);
                    label = r.token;
                    r.nextToken;
                    break;
                case END:
                    break;
                case PREFIX:
                    break;
                case SYMBOL:
                    r.nextToken;
                    for (uint i = 0; (instr.push == uint.max) ? r.type == TokenType.WORD : i < instr.push; i++) {
                        label = r.token;
                        r.nextToken;
                    }
                    for (uint i = 0; (instr.pops == uint.max) ? r.type == TokenType.BEGIN : i < instr.pops; i++) {
                        parseInstr(r, ParserStage.CODE);

                    }
                }
            }

        }
        else {
            r.check(false);
        }

        return stage;
    }

    private ParserStage parseModule(ref WastTokenizer r, const ParserStage stage) {
        if (r.type == TokenType.BEGIN) {
            string label;
            string arg;
            r.nextToken;
            bool not_ended;
            scope (exit) {
                r.check(r.type == TokenType.END || not_ended);
                r.nextToken;
            }
            switch (r.token) {
            case "module":
                r.check(stage < ParserStage.MODULE);
                r.nextToken;
                while (r.type == TokenType.BEGIN) {
                    parseModule(r, ParserStage.MODULE);

                }
                return ParserStage.MODULE;
            case "type":
                r.nextToken;

                if (stage == ParserStage.MODULE) {
                    if (r.type == TokenType.WORD) {
                        label = r.token;
                        r.nextToken;
                    }
                    parseModule(r, ParserStage.TYPE);
                    return stage;
                }
                //if (stage == ParserStage.FUNC) {
                r.check(r.type == TokenType.WORD);
                label = r.token;
                r.nextToken;
                return ParserStage.TYPE;
                //}
                //return stage;
            case "func": // Example (func $name (param ...) (result i32) )
                return parseTypeSection(r, stage);
            case "param": // Example (param $y i32)
                r.nextToken;
                if (stage == ParserStage.IMPORT) {
                    Types[] wasm_types;
                    while (r.token.getType !is Types.EMPTY) {
                        wasm_types ~= r.token.getType;
                        r.nextToken;
                    }
                }
                else {
                    r.check(stage == ParserStage.FUNC);

                    if (r.type == TokenType.WORD && r.token.getType is Types.EMPTY) {
                        label = r.token;
                        r.nextToken;

                        r.check(r.type == TokenType.WORD);
                    }
                    while (r.type == TokenType.WORD && r.token.getType !is Types.EMPTY) {
                        arg = r.token;
                        r.nextToken;
                    }
                }
                return ParserStage.PARAM;
            case "result":
                r.check(stage == ParserStage.FUNC);
                r.nextToken;
                r.check(r.type == TokenType.WORD);
                arg = r.token;
                r.nextToken;
                return ParserStage.RESULT;
            case "memory":
                r.check(stage == ParserStage.MODULE);
                r.nextToken;
                r.check(r.type == TokenType.WORD);
                label = r.token;

                r.nextToken;
                if (r.type == TokenType.WORD) {
                    arg = r.token;
                    r.nextToken;
                }
                while (r.type == TokenType.BEGIN) {
                    parseModule(r, ParserStage.MEMORY);
                }
                return ParserStage.MEMORY;
            case "segment":
                r.nextToken;
                r.check(r.type == TokenType.WORD);
                label = r.token;
                r.nextToken;
                r.check(r.type == TokenType.STRING);
                arg = r.token;
                r.nextToken;
                break;
            case "export":
                r.check(stage == ParserStage.MODULE);

                r.nextToken;
                r.check(r.type == TokenType.STRING);
                label = r.token;
                r.nextToken;
                arg = r.token;
                r.check(r.type == TokenType.WORD);
                r.nextToken;
                return ParserStage.EXPORT;
            case "import":
                string arg2;
                r.nextToken;
                r.check(r.type == TokenType.WORD);
                label = r.token;
                r.nextToken;
                r.check(r.type == TokenType.STRING);
                arg = r.token;
                r.nextToken;
                r.check(r.type == TokenType.STRING);
                arg2 = r.token;
                r.nextToken;
                const ret = parseModule(r, ParserStage.IMPORT);
                r.check(ret == ParserStage.TYPE || ret == ParserStage.PARAM);

                return stage;
            case "assert_return":
                r.check(stage == ParserStage.BASE);
                label = r.token;
                r.nextToken;

                // Invoke call
                parseInstr(r, ParserStage.ASSERT);
                if (r.type == TokenType.BEGIN) {
                    parseInstr(r, ParserStage.EXPECTED);
                }
                return ParserStage.ASSERT;
            case "assert_trap":
                r.check(stage == ParserStage.BASE);
                label = r.token;
                r.nextToken;
                // Invoke call
                parseInstr(r, ParserStage.ASSERT);

                r.check(r.type == TokenType.STRING);
                arg = r.token;
                r.nextToken;
                return ParserStage.ASSERT;
            case "assert_return_nan":
                r.check(stage == ParserStage.BASE);
                label = r.token;
                r.nextToken;
                // Invoke call
                parseInstr(r, ParserStage.ASSERT);

                return ParserStage.ASSERT;
            case "assert_invalid":
                r.check(stage == ParserStage.BASE);
                r.nextToken;
                parseModule(r, ParserStage.ASSERT);
                r.check(r.type == TokenType.STRING);
                arg = r.token;
                r.nextToken;
                return ParserStage.ASSERT;
            default:
                if (r.type == TokenType.COMMENT) {
                    r.nextToken;
                    return ParserStage.COMMENT;
                }
                not_ended = true;
                r.nextToken;
                return ParserStage.UNDEFINED;
            }
        }
        if (r.type == TokenType.COMMENT) {
            r.nextToken;
        }
        return ParserStage.END;
    }

    private ParserStage parseTypeSection(ref WastTokenizer r, const ParserStage stage) {
        string label;

        r.check(stage < ParserStage.FUNC);
        auto type_section = writer.section!(Section.TYPE);

        const type_idx = type_section.sectypes.length;

        writefln("%s", type_section.sectypes.length);
        r.nextToken;
        if (r.type == TokenType.WORD) {
            // Function with label
            label = r.token;
            r.nextToken;
        }
        ParserStage arg_stage;
        WastTokenizer rewined;
        uint only_one_type_allowed;
        do {
            rewined = r.save;
            arg_stage = parseModule(r, ParserStage.FUNC);

            only_one_type_allowed += (only_one_type_allowed > 0) || (arg_stage == ParserStage.TYPE);

            //count_types+=(arg_stage == ParserStage.TYPE);
        }
        while ((arg_stage == ParserStage.PARAM) || (only_one_type_allowed == 1));
        //auto result_r=r.save;
        if (arg_stage != ParserStage.TYPE && arg_stage != ParserStage.RESULT || arg_stage == ParserStage
                .UNDEFINED) {
            r = rewined;
        }
        while (r.type == TokenType.BEGIN) {
            const ret = parseInstr(r, ParserStage.FUNC_BODY);
            r.check(ret == ParserStage.FUNC_BODY);
        }
        return ParserStage.FUNC;
    }

    void parse(ref WastTokenizer tokenizer) {
        uint[string] func_idx;

        while (parseModule(tokenizer, ParserStage.BASE) !is ParserStage.END) {
            //empty    
        }

    }

}

version (WAST) @safe
unittest {
    import tagion.basic.basic : unitfile;
    import std.file : readText;
    import std.stdio;

    immutable wast_test_files = [
        "i32.wast",
        "f32.wast",
        "i64.wast",
        "f64.wast",
        "f32_cmp.wast",
        "f64_cmp.wast",
        "float_exprs.wast",
        "unreachable.wast",
        "float_literals.wast",
        "float_memory.wast",
        "float_misc.wast",
        "conversions.wast",
        "endianness.wast",
        "traps.wast",
        "runaway-recursion.wast",
        "nan-propagation.wast",
        "forward.wast",
        "func_ptrs.wast",
        "functions.wast",
        // "has_feature.wast",
        "imports.wast",
        "int_exprs.wast",
        "int_literals.wast",
        "labels.wast",
        "left-to-right.wast",
        "memory_redundancy.wast",
        "memory_trap.wast",
        "memory.wast",
        "resizing.wast",
        "select.wast",
        "store_retval.wast",
        "switch.wast",
    ];
    version (none) immutable wast_test_files = [
        "unreachable.wast",
        /*
        "float_literals.wast",
        "float_memory.wast",
        "float_misc.wast",
        "conversions.wast",
        "endianness.wast",
        "traps.wast",
        "runaway-recursion.wast",
        "nan-propagation.wast",
        "forward.wast",
        "func_ptrs.wast",
        "functions.wast",
        "has_feature.wast",
        "imports.wast",
        "int_exprs.wast",
        "int_literals.wast",
        "labels.wast",
        "left-to-right.wast",
        "memory_redundancy.wast",
        "memory_trap.wast",
        "memory.wast",
        "resizing.wast",
        "select.wast",
        "store_retval.wast",
        "switch.wast",
*/
    ];
    foreach (wast_file; wast_test_files) {
        immutable wast_text = wast_file.unitfile.readText;
        writefln("wast_file %s", wast_file);
        auto tokenizer = WastTokenizer(wast_text);
        auto writer = new WasmWriter;
        auto wast_parser = WastParser(writer);
        wast_parser.parse(tokenizer);
    }
}
