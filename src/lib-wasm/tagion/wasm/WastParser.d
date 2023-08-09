module tagion.wasm.WastParser;

import tagion.wasm.WastTokenizer;
import tagion.wasm.WasmWriter;
import tagion.wasm.WasmBase;
import tagion.basic.Debug;
import std.stdio;
import std.exception : ifThrown;
import core.exception : RangeError;
import std.conv;
import std.traits;
import std.algorithm;
import std.array;

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

    struct Register {
        int idx;
        Types type;
    }

    private ParserStage parseInstr(ref WastTokenizer r,
            const ParserStage stage,
            ref CodeType code_type,
            ref const(FuncType) func_type, //scope immutable(Types)[] locals,
            ref scope int[string] params) {
        import tagion.wasm.WasmExpr;
        import std.outbuffer;

        immutable number_of_func_arguments = func_type.params.length;
        scope immutable(Types)[] locals = func_type.params;
        auto bout = new OutBuffer;
        auto wasmexpr = WasmExpr(bout);
        int getLocal(string text) @trusted {
            int result = params[r.token].ifThrown!RangeError(int(-1));
            if (result < 0) {
                result = r.token
                    .to!int
                    .ifThrown!ConvException(-1);
                r.check(result >= 0);
            }
            return result;
        }

        writefln("%s %s", __FUNCTION__, params.dup);
        ParserStage innerInstr(ref WastTokenizer r, const ParserStage) {
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
                            innerInstr(r, ParserStage.CODE);
                        }
                        wasmexpr(irLookupTable[instr.name]);
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
                            innerInstr(r, ParserStage.CODE);
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
                            innerInstr(r, ParserStage.CODE);
                        }
                        break;
                    case BRANCH_IF:
                        r.nextToken;
                        innerInstr(r, ParserStage.CODE);
                        r.check(r.type == TokenType.WORD);
                        label = r.token;
                        r.nextToken;
                        if (r.type == TokenType.BEGIN) {
                            innerInstr(r, ParserStage.CODE);
                        }
                        break;
                    case BRANCH_TABLE:
                        break;
                    case CALL:
                        r.nextToken;
                        label = r.token;
                        r.nextToken;
                        while (r.type == TokenType.BEGIN) {
                            innerInstr(r, ParserStage.CODE);
                        }

                        break;
                    case CALL_INDIRECT:
                        break;
                    case LOCAL:

                        //string arg;
                        r.nextToken;
                        label = r.token;
                        r.check(r.type == TokenType.WORD);
                        //r.nextToken;
                        //r.check(r.type != TokenType.WORD);
                        //if (r.type == TokenType.WORD) {
                        const local_idx = getLocal(r.token);
                        wasmexpr(irLookupTable[instr.name], local_idx);
                        //.ifThrown!RangeError(-1);

                        //arg = r.token;
                        r.nextToken;
                        //  r.check(r.type != TokenType.WORD);
                        /*        
                }
                        else {
*/
                        foreach (i; 0 .. instr.pops) {
                            innerInstr(r, ParserStage.CODE);
                        }
                        //                        }

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
                            innerInstr(r, ParserStage.CODE);
                        }
                        break;
                    case MEMOP:
                        r.nextToken;
                        foreach (i; 0 .. instr.pops) {
                            innerInstr(r, ParserStage.CODE);
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
                        string[] labels;
                        for (uint i = 0; (instr.push == uint.max) ? r.type == TokenType.WORD : i < instr.push; i++) {
                            labels ~= r.token;
                            r.nextToken;
                        }
                        for (uint i = 0; (instr.pops == uint.max) ? r.type == TokenType.BEGIN : i < instr.pops; i++) {
                            innerInstr(r, ParserStage.CODE);

                        }
                        switch (instr.wast) {
                        case PseudoWastInstr.local:
                            r.check(labels.length >= 1);
                            if ((labels.length == 2) && (labels[1].getType !is Types.EMPTY)) {
                                params[labels[0]] = cast(int) locals.length;
                                locals ~= labels[1].getType;
                                break;
                            }
                            locals ~= labels.map!(l => l.getType).array;
                            break;
                        default:

                        }
                    }
                }

            }
            else {
                r.check(false);
            }
            return stage;
        }

        scope (exit) {
            writefln("%(%02X %)", wasmexpr.serialize);
            if (locals.length > number_of_func_arguments) {
                writefln("locals=%s", params.dup);
            }
            code_type = CodeType(locals[number_of_func_arguments .. $], wasmexpr.serialize);
        }
        return innerInstr(r, stage);
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
                if (r.type == TokenType.WORD) {
                    label = r.token;
                    r.nextToken;
                }
                parseModule(r, ParserStage.TYPE);
                return stage;
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
                ExportType export_type;
                scope (exit) {
                    writer.section!(Section.EXPORT).sectypes ~= export_type;
                }
                r.check(stage == ParserStage.MODULE);

                r.nextToken;
                r.check(r.type == TokenType.STRING);
                export_type.name = r.token.stripQuotes;
                r.nextToken;
                //arg = r.token;
                r.check(r.type == TokenType.WORD);
                export_type.desc = IndexType.FUNC;
                writefln("r.token=%s %s", r.token, func_idx);
                export_type.idx = func_idx.get(r.token, -1);
                r.check(export_type.idx >= 0);

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
                FuncType func_type;
                scope Type[] locals;
                scope int[string] params;
                const ret = parseFuncArgs(r, ParserStage.IMPORT, func_type, params);
                r.check(ret == ParserStage.TYPE || ret == ParserStage.PARAM);

                return stage;
            case "assert_return":
                r.check(stage == ParserStage.BASE);
                label = r.token;
                r.nextToken;
                FuncType func_type;
                CodeType code_type;
                scope int[string] params;
                // Invoke call
                parseInstr(r, ParserStage.ASSERT, code_type, func_type, params);
                if (r.type == TokenType.BEGIN) {
                    parseInstr(r, ParserStage.EXPECTED, code_type, func_type, params);
                }
                return ParserStage.ASSERT;
            case "assert_trap":
                r.check(stage == ParserStage.BASE);
                label = r.token;
                r.nextToken;
                FuncType func_type;
                CodeType code_type;
                scope Types[] locals;
                scope int[string] params;
                // Invoke call
                parseInstr(r, ParserStage.ASSERT, code_type, func_type, params);

                r.check(r.type == TokenType.STRING);
                arg = r.token;
                r.nextToken;
                return ParserStage.ASSERT;
            case "assert_return_nan":
                r.check(stage == ParserStage.BASE);
                label = r.token;
                r.nextToken;
                FuncType func_type;
                CodeType code_type;
                scope Types[] locals;
                scope int[string] params;
                // Invoke call
                parseInstr(r, ParserStage.ASSERT, code_type, func_type, params);

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

    private ParserStage parseFuncArgs(
            ref WastTokenizer r,
            const ParserStage stage,
            ref FuncType func_type,
            ref scope int[string] params) {
        if (r.type == TokenType.BEGIN) {
            //string label;
            string arg;
            r.nextToken;
            bool not_ended;
            scope (exit) {
                r.check(r.type == TokenType.END || not_ended);
                r.nextToken;
            }
            switch (r.token) {
            case "type":
                r.nextToken;
                r.check(r.type == TokenType.WORD);
                //label = r.token;
                r.nextToken;
                return ParserStage.TYPE;
            case "param": // Example (param $y i32)
                r.nextToken;
                if (stage == ParserStage.IMPORT) {
                    while (r.token.getType !is Types.EMPTY) {
                        func_type.params ~= r.token.getType;
                        r.nextToken;
                    }
                }
                else {
                    r.check(stage == ParserStage.FUNC);

                    if (r.type == TokenType.WORD && r.token.getType is Types.EMPTY) {
                        const label = r.token;
                        r.nextToken;

                        r.check(r.type == TokenType.WORD);
                        params[label] = cast(int) func_type.params.length;
                        func_type.params ~= r.token.getType;
                        r.check(r.token.getType !is Types.EMPTY);
                        r.nextToken;
                    }
                    while (r.type == TokenType.WORD && r.token.getType !is Types.EMPTY) {
                        func_type.params ~= r.token.getType;
                        //arg = r.token;
                        r.nextToken;
                    }
                }
                return ParserStage.PARAM;
            case "result":
                r.check(stage == ParserStage.FUNC);
                r.nextToken;
                r.check(r.type == TokenType.WORD);

                //arg = r.token;
                func_type.results = [r.token.getType];
                r.check(r.token.getType !is Types.EMPTY);
                r.nextToken;
                return ParserStage.RESULT;
            default:
                not_ended = true;
                r.nextToken;
                return ParserStage.UNDEFINED;
            }
        }
        return ParserStage.UNDEFINED;
    }

    private ParserStage parseTypeSection(ref WastTokenizer r, const ParserStage stage) {
        //string label;
        CodeType code_type;
        writeln("Function code");
        scope (exit) {
            writer.section!(Section.CODE).sectypes ~= code_type;
            writefln("%s %s", Section.CODE, writer.section!(Section.CODE).sectypes.length);
        }

        r.check(stage < ParserStage.FUNC);
        auto type_section = writer.section!(Section.TYPE);

        const type_idx = cast(int) type_section.sectypes.length;
        FuncType func_type;
        scope int[string] params;
        //scope Types[] locals;
        scope (exit) {
            type_section.sectypes ~= func_type;
        }

        r.nextToken;
        if (r.type == TokenType.WORD) {
            // Function with label
            //label = r.token;
            func_idx[r.token] = type_idx;
            r.nextToken;
        }
        ParserStage arg_stage;
        WastTokenizer rewined;
        uint only_one_type_allowed;
        do {
            rewined = r.save;
            arg_stage = parseFuncArgs(r, ParserStage.FUNC, func_type, params);

            only_one_type_allowed += (only_one_type_allowed > 0) || (arg_stage == ParserStage.TYPE);
        }
        while ((arg_stage == ParserStage.PARAM) || (only_one_type_allowed == 1));
        //auto result_r=r.save;
        if (arg_stage != ParserStage.TYPE && arg_stage != ParserStage.RESULT ||
                arg_stage == ParserStage.UNDEFINED) {
            r = rewined;
        }
        while (r.type == TokenType.BEGIN) {
            const ret = parseInstr(r, ParserStage.FUNC_BODY, code_type, func_type, params);
            r.check(ret == ParserStage.FUNC_BODY);
        }
        return ParserStage.FUNC;
    }

    private {
        int[string] func_idx;
    }
    void parse(ref WastTokenizer tokenizer) {

        while (parseModule(tokenizer, ParserStage.BASE) !is ParserStage.END) {
            //empty    
        }
        static foreach (Sec; EnumMembers!Section) {
            static if (Sec !is Section.CUSTOM && Sec !is Section.START) {
                writefln("%s sectypes.length=%d", Sec, writer.section!Sec.sectypes.length);
            }
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
    import std.file : fwrite = write;

    foreach (wast_file; wast_test_files) {
        immutable wast_text = wast_file.unitfile.readText;
        writefln("wast_file %s", wast_file);
        auto tokenizer = WastTokenizer(wast_text);
        auto writer = new WasmWriter;
        auto wast_parser = WastParser(writer);
        wast_parser.parse(tokenizer);
        if (wast_file == "i32.wast") {
            static foreach (Sec; EnumMembers!Section) {
                static if (Sec !is Section.CUSTOM && Sec !is Section.START) {
                    writefln("After parser %s sectypes.length=%d", Sec, writer.section!Sec.sectypes.length);
                }
            }
            "/tmp/i32.wasm".fwrite(writer.serialize);
        }
    }

}
