module tagion.wasm.WastParser;

import core.exception : RangeError;
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.stdio;
import std.traits;
import tagion.basic.Debug;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmWriter;
import tagion.wasm.WastAssert;
import tagion.wasm.WastTokenizer;
import tagion.wasm.WasmExpr;
import tagion.wasm.WasmException;
import tagion.basic.basic : isinit;

@safe:

struct WastParser {
    WasmWriter writer;
    SectionAssert wast_assert;
    private void writeCustomAssert() {
        if (wast_assert !is SectionAssert.init) {
            auto _custom = new CustomType("assert", wast_assert.toDoc);
            auto custom_sec = writer.section!(Section.CUSTOM);
            custom_sec.list[Section.DATA] ~= _custom;
        }
    }

    alias WasmSection = WasmWriter.WasmSection;
    this(WasmWriter writer) @nogc pure nothrow {
        this.writer = writer;
    }

    alias GlobalDesc = WasmSection.ImportType.ImportDesc.GlobalDesc;
    alias Global = WasmSection.Global;
    alias Type = WasmSection.Type;
    alias Function = WasmSection.Function;
    alias Code = WasmSection.Code;
    alias Memory = WasmSection.Memory;
    alias MemoryType = WasmSection.MemoryType;
    alias GlobalType = WasmSection.GlobalType;
    alias FuncType = WasmSection.FuncType;
    alias FuncIndex = WasmSection.FuncIndex;
    alias CodeType = WasmSection.CodeType;
    alias DataType = WasmSection.DataType;
    alias ExportType = WasmSection.ExportType;
    alias CustomType = WasmSection.Custom;

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
        BREAK,
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

    struct Block {
        int idx;
        const(Types)[] types;
        string label;
    }

    struct FunctionContext {
        Block[] block_stack;
        const(Types)[] locals;
        int[string] local_names;
        int blk_idx;

        void block_push(const int idx) pure nothrow {
            block_stack ~= Block(idx);
        }

        void block_push(const(Types[]) types, string label) pure nothrow {
            block_stack ~= Block(blk_idx++, types, label);
        }

        Block block_pop() pure {
            if (block_stack.length == 0) {
                throw new WasmException("Block stack empty");
            }
            scope (exit) {
                block_stack.length--;
            }
            return block_stack[$ - 1];
        }

        Block block_peek(const int idx) const pure nothrow {
            if ((idx >= block_stack.length) || (idx < 0)) {
                return Block(-1);
            }
            return block_stack[$ - idx - 1];
        }

        Block block_peek(string token) const pure nothrow {
            int idx = assumeWontThrow(
                    token.to!int
                    .ifThrown(cast(int) block_stack.countUntil!(b => b.label == token))
                    .ifThrown(-1));
            return block_peek(idx);
        }

        Types localType(const int idx) {
            check(idx >= 0 && idx < locals.length, format("Local register index %d is not available", idx));
            return locals[idx];
        }

    }

    static void setLocal(ref WastTokenizer tokenizer, ref FunctionContext func_ctx) {
        auto r = tokenizer.save;
        bool innerLocal() {
            if (r.type == TokenType.BEGIN) {
                r.nextToken;
                if (r.token == "local") {
                    r.nextToken;
                    if (r.token.getType == Types.EMPTY) {
                        const name = r.token;
                        r.nextToken;
                        const wasm_type = r.token.getType;
                        tokenizer.valid(wasm_type != Types.EMPTY, format("Invalid type %s", r.token));
                        r.nextToken;
                        func_ctx.local_names[name] = cast(int) func_ctx.locals.length;
                        func_ctx.locals ~= wasm_type;
                    }
                    else {
                        while (r.token.getType != Types.EMPTY) {
                            func_ctx.locals ~= r.token.getType;
                            r.nextToken;
                        }
                    }
                    r.expect(TokenType.END);
                    r.nextToken;
                    tokenizer = r;
                    return true;
                }
            }
            return false;
        }

        while (innerLocal) {
            // empty
        }
    }

    unittest {
        {
            FunctionContext func_ctx;
            const text = "(local i32) (local i32 f32) (local $x f64) (none_local xxx)";
            auto r = WastTokenizer(text);
            setLocal(r, func_ctx);
            assert(equal(func_ctx.locals, [Types.I32, Types.I32, Types.F32, Types.F64]));
            assert(func_ctx.local_names["$x"] == 3);
            assert(equal(r.map!(t => t.token), ["(", "none_local", "xxx", ")"]));
        }
    }

    private ParserStage _parseInstr(
            ref WastTokenizer r,
            const ParserStage stage,
            ref WasmExpr func_wasmexpr, //ref CodeType code_type,
            ref const(FuncType) func_type,
            ref FunctionContext func_ctx) {
        int getLocal(ref WastTokenizer tokenizer) @trusted {
            int result = func_ctx.local_names[tokenizer.token].ifThrown!RangeError(int(-1));
            if (result < 0) {
                result = tokenizer.token
                    .to!int
                    .ifThrown!ConvException(-1);
                tokenizer.valid(result >= 0, "Local register expected");
            }
            return result;
        }

        bool got_error;

        void parser_check(ref WastTokenizer tokenizer,
                const bool flag,
                string msg = null,
                string file = __FILE__,
                const size_t code_line = __LINE__) nothrow {
            got_error |= tokenizer.valid(flag, msg, file, code_line);
        }

        int getFuncIdx() @trusted {
            int innerFunc(string text) {
                int result = func_lookup[text].ifThrown!RangeError(int(-1));
                if (result < 0) {
                    result = text.to!int
                        .ifThrown!ConvException(-1);
                    parser_check(r, result >= 0, format("Invalid function %s name or index", text));
                }
                return result;
            }

            switch (r.type) {
            case TokenType.WORD:
                return innerFunc(r.token);
            case TokenType.STRING:
                // if (writer.section!(Section.EXPORT)!is null) {
                auto export_found = writer.section!(Section.EXPORT)
                    .sectypes
                    .find!(exp => exp.name == r.token.stripQuotes);
                if (!export_found.empty) {
                    return export_found.front.idx;
                }
                //}

                break;
            default:
                // empty
            }
            parser_check(r, 0, format("Export %s is not defined", r.token));

            return -1;
        }

        scope (exit) {
            if (got_error) {
                r.dropScopes;
            }
        }

        ParserStage innerInstr(ref WasmExpr wasmexpr,
                ref WastTokenizer r,
                const(Types[]) block_results,
                ParserStage instr_stage) @safe {
            //try {
            scope (failure) {
                r.dropScopes;
            }
            scope (exit) {
                r.expect(TokenType.END, "Expect an end ')'");
                r.nextToken;
                if (func_wasmexpr != wasmexpr) {
                    func_wasmexpr.append(wasmexpr);
                }
            }
            static const(Types)[] getReturns(ref WastTokenizer r) @safe {
                Types[] results;
                if (r.BEGIN) {
                    auto r_return = r.save;
                    r_return.nextToken;

                    if (r_return.token == "result") {
                        r_return.nextToken;
                        while (r_return.WORD) {
                            r_return.expect(TokenType.WORD);
                            results ~= r_return.token.getType;
                            r_return.nextToken;
                        }
                        r_return.expect(TokenType.END);
                        r_return.nextToken;
                        r = r_return;
                    }
                }
                return results;
            }

            if (r.EOF) {
                return instr_stage;
            }
            r.expect(TokenType.BEGIN);
            r.nextToken;
            r.expect(TokenType.WORD);
            const instr = instrWastLookup.get(r.token, illegalInstr);
            //__write("instr %s", instr);
            string label;
            with (IRType) {
                final switch (instr.irtype) {
                case CODE:
                    r.nextToken;
                    while (r.BEGIN) {
                        instr_stage = innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                    }
                    wasmexpr(irLookupTable[instr.name]);
                    break;
                case CODE_EXTEND:
                    r.nextToken;
                    while (r.BEGIN) {
                        instr_stage = innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                    }
                    wasmexpr(IR.EXNEND, instr.opcode);
                    break;
                case CODE_TYPE:
                    r.nextToken;
                    auto wasm_results = getReturns(r);
                    if (wasm_results.empty) {
                        wasm_results = block_results;
                    }
                    while (r.BEGIN) {
                        instr_stage = innerInstr(wasmexpr, r, wasm_results, ParserStage.CODE);
                        //breakout |= (sub_stage == ParserStage.END);
                    }
                    wasmexpr(irLookupTable[instr.name]);
                    break;
                case RETURN:
                    r.nextToken;
                    while (r.BEGIN) {
                        instr_stage = innerInstr(wasmexpr, r, func_type.results, ParserStage.CODE);
                    }
                    wasmexpr(irLookupTable[instr.name]);
                    break;
                case BLOCK:
                    r.nextToken;
                    label = null;
                    if (r.type == TokenType.WORD) {
                        label = r.token;
                        r.nextToken;
                    }
                    scope (success) {
                        func_ctx.block_pop;
                        wasmexpr(IR.END);
                    }
                    const wasm_results = getReturns(r);
                    if (wasm_results.length == 0) {
                        wasmexpr(irLookupTable[instr.name], Types.EMPTY);
                    }
                    else if (wasm_results.length == 1) {
                        wasmexpr(irLookupTable[instr.name], wasm_results[0]);
                    }
                    else {
                        auto func_type = FuncType(Types.FUNC, null, wasm_results.idup);
                        const type_idx = writer.createTypeIdx(func_type);
                        wasmexpr(irLookupTable[instr.name], type_idx);
                    }
                    func_ctx.block_push(wasm_results, label);
                    while (r.BEGIN) {
                        innerInstr(wasmexpr, r, wasm_results, ParserStage.CODE);
                    }
                    return stage;
                case BRANCH:
                    switch (r.token) {
                    case getInstr!(IR.BR).wast:
                        r.nextToken;
                        const blk = func_ctx.block_peek(r.token);
                        r.nextToken;
                        while (r.BEGIN) {
                            instr_stage = innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                        }
                        wasmexpr(IR.BR, blk.idx);
                        break;
                    default:
                        assert(0, format("Illegal token %s in %s", r.token, BRANCH));
                    }
                    while (r.type == TokenType.BEGIN) {
                        innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                    }
                    break;
                case BRANCH_TABLE:
                    break;
                case CALL:
                    r.nextToken;
                    const func_idx = getFuncIdx();
                    r.nextToken;
                    while (r.BEGIN) {
                        instr_stage = innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                    }
                    wasmexpr(IR.CALL, func_idx);
                    break;
                case CALL_INDIRECT:
                    break;
                case LOCAL:
                    r.nextToken;
                    r.expect(TokenType.WORD);
                    const local_idx = getLocal(r);
                    const local_type = func_ctx.localType(local_idx);
                    r.nextToken;
                    foreach (i; 0 .. instr.pops.length) {
                        innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                    }
                    wasmexpr(irLookupTable[instr.name], local_idx);
                    break;
                case GLOBAL:
                    r.nextToken;
                    label = r.token;
                    r.expect(TokenType.WORD);
                    r.nextToken;
                    break;
                case MEMORY:

                    r.nextToken;
                    for (uint i = 0; (i < 2) && (r.type == TokenType.WORD); i++) {
                        label = r.token; // Fix this later
                        r.nextToken;
                    }
                    foreach (i; 0 .. instr.pops.length) {
                        innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                    }
                    break;
                case MEMOP:
                    r.nextToken;
                    foreach (i; 0 .. instr.pops.length) {
                        innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                    }
                    break;
                case CONST:
                    r.nextToken;
                    r.expect(TokenType.WORD);
                    const ir = irLookupTable[instr.name];
                    with (IR) switch (ir) {
                    case I32_CONST:
                        wasmexpr(ir, r.get!int);
                        break;
                    case I64_CONST:
                        wasmexpr(ir, r.get!long);
                        break;
                    case F32_CONST:
                        wasmexpr(ir, r.get!float);
                        break;
                    case F64_CONST:
                        wasmexpr(ir, r.get!double);
                        break;
                    default:
                        parser_check(r, 0, "Bad const instruction");
                    }
                    r.nextToken;
                    break;
                case END:
                    break;
                case PREFIX:
                    break;
                case ILLEGAL:
                    throw new WasmException(format("Undefined instruction %s", r.token));
                    break;
                case SYMBOL:
                    check(0, "Pseudo instruction not allowed");
                }

            }
            /*
            }
            catch (Exception e) {
                r.error(e);
                r.dropScopes;
            }
                        */
            return instr_stage;
        }

        setLocal(r, func_ctx);
        return innerInstr(func_wasmexpr, r, func_type.results, stage);

    }

    private ParserStage parseInstr(
            ref WastTokenizer r,
            const ParserStage stage,
            ref CodeType code_type,
            ref const(FuncType) func_type,
            ref FunctionContext func_ctx) {
        immutable number_of_func_arguments = func_type.params.length;
        static WasmExpr createWasmExpr() {
            import std.outbuffer;

            auto bout = new OutBuffer;
            return WasmExpr(bout);
        }

        auto func_wasmexpr = createWasmExpr;
        scope (exit) {
            code_type = CodeType(func_ctx.locals[number_of_func_arguments .. $], func_wasmexpr.serialize);
        }
        //__write("Instr %s %s", func_type, stage);
        scope (exit) {
            func_wasmexpr(IR.END);
        }
        if (stage is ParserStage.FUNC_BODY) {
            ParserStage result;
            uint count;
            while (r.type == TokenType.BEGIN) {
                result = _parseInstr(r, stage, func_wasmexpr, func_type, func_ctx);
                count++;
            }
            return result;
        }
        return _parseInstr(r, stage, func_wasmexpr, func_type, func_ctx);
        //return _parseInstr(r, stage, func_wasmexpr, func_type, func_ctx);
    }

    private ParserStage parseModule(ref WastTokenizer r, const ParserStage stage) {
        if (r.type == TokenType.COMMENT) {
            r.nextToken;
        }
        if (r.type == TokenType.BEGIN) {
            string label;
            string arg;
            r.nextToken;
            bool not_ended;
            scope (exit) {
                r.valid(r.type == TokenType.END || not_ended, "Missing end");
                r.nextToken;
            }
            switch (r.token) {
            case "module":
                r.valid(stage < ParserStage.MODULE, "Module expected");
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
                //__write("-- FUNC %s %s", r.token, r.type);
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
                    r.valid(stage == ParserStage.FUNC, "Only allowed inside a function scope");

                    if (r.type == TokenType.WORD && r.token.getType is Types.EMPTY) {
                        label = r.token;
                        r.nextToken;

                        r.expect(TokenType.WORD);
                    }
                    while (r.type == TokenType.WORD && r.token.getType !is Types.EMPTY) {
                        arg = r.token;
                        r.nextToken;
                    }
                }
                return ParserStage.PARAM;
            case "result":
                r.valid(stage == ParserStage.FUNC, "Result only allowed inside function declaration");
                r.nextToken;
                r.expect(TokenType.WORD);
                arg = r.token;
                r.nextToken;
                return ParserStage.RESULT;
            case "memory":
                MemoryType memory_type;
                scope (exit) {
                    writer.section!(Section.MEMORY).sectypes ~= memory_type;
                }
                r.valid(stage == ParserStage.MODULE, "Memory statement only allowed after memory");
                r.nextToken;
                r.expect(TokenType.WORD);
                label = r.token;
                writef("Memory label = %s", label);
                r.nextToken;
                if (r.type == TokenType.WORD) {
                    arg = r.token;
                    writef("arg = %s", arg);
                    r.nextToken;
                    memory_type.limit.lim = Limits.RANGE;
                    memory_type.limit.to = arg.to!uint;
                    memory_type.limit.from = label.to!uint;

                }
                else {
                    memory_type.limit.lim = Limits.RANGE;
                    memory_type.limit.to = label.to!uint;
                }
                writefln("Type %s", r.type);
                while (r.type == TokenType.BEGIN) {
                    parseModule(r, ParserStage.MEMORY);
                }
                return ParserStage.MEMORY;
            case "segment":
                DataType data_type;
                scope (exit) {
                    writer.section!(Section.DATA).sectypes ~= data_type;
                }
                r.valid(stage == ParserStage.MEMORY, "Memory section expected");
                r.nextToken;
                r.expect(TokenType.WORD);
                data_type.mode = DataMode.PASSIVE;
                data_type.memidx = r.get!int;
                r.nextToken;
                data_type.base = r.getText;
                r.nextToken;
                break;
            case "export":
                ExportType export_type;
                scope (exit) {
                    writer.section!(Section.EXPORT).sectypes ~= export_type;
                }
                r.valid(stage == ParserStage.MODULE || stage == ParserStage.FUNC, "Function or module stage expected");

                r.nextToken;
                r.expect(TokenType.STRING);
                export_type.name = r.token.stripQuotes;
                if (stage != ParserStage.FUNC) {
                    r.nextToken;
                    r.expect(TokenType.WORD);
                    export_type.idx = func_lookup.get(r.token, -1);
                }
                export_type.desc = IndexType.FUNC;
                r.valid(export_type.idx >= 0, "Export index should be positive or zero");

                r.nextToken;
                return ParserStage.EXPORT;
            case "import":
                string arg2;
                r.nextToken;
                r.expect(TokenType.WORD);
                label = r.token;
                r.nextToken;
                r.expect(TokenType.STRING);
                arg = r.token;
                r.nextToken;
                r.expect(TokenType.STRING);
                arg2 = r.token;
                r.nextToken;
                FuncType func_type;
                const ret = parseFuncArgs(r, ParserStage.IMPORT, func_type);
                r.valid(ret == ParserStage.TYPE || ret == ParserStage.PARAM, "Import state only allowed inside type or param");

                return stage;
            case "assert_return_nan":
            case "assert_return":
                r.valid(stage == ParserStage.BASE, "Assert not allowed here");
                Assert assert_type;
                if (r.token == "assert_return_nan") {
                    assert_type.method = Assert.Method.Return_nan;
                }
                else {
                    assert_type.method = Assert.Method.Return;
                }
                assert_type.name = r.token;
                r.nextToken;
                FuncType func_type;
                CodeType code_invoke;
                CodeType code_result;
                FunctionContext func_ctx;
                parseInstr(r, ParserStage.ASSERT, code_invoke, func_type, func_ctx);
                while (r.type == TokenType.BEGIN) {
                    parseInstr(r, ParserStage.EXPECTED, code_result, func_type, func_ctx);
                }
                //assert_type.results = func_ctx.stack;
                assert_type.invoke = code_invoke.serialize;
                assert_type.result = code_result.serialize;
                wast_assert.asserts ~= assert_type;
                return ParserStage.ASSERT;
            case "assert_trap":
                r.valid(stage == ParserStage.BASE, "Assert not allowed here");
                Assert assert_type;
                assert_type.method = Assert.Method.Trap;
                assert_type.name = r.token;
                label = r.token;
                r.nextToken;
                FuncType func_type;
                CodeType code_invoke;
                FunctionContext func_ctx;
                parseInstr(r, ParserStage.ASSERT, code_invoke, func_type, func_ctx);
                assert_type.invoke = code_invoke.serialize;

                r.expect(TokenType.STRING);
                assert_type.message = r.token;
                wast_assert.asserts ~= assert_type;
                r.nextToken;
                return ParserStage.ASSERT;
            case "assert_invalid":
                r.valid(stage == ParserStage.BASE, "Assert not allowed here");
                r.nextToken;
                parseModule(r, ParserStage.ASSERT);
                r.expect(TokenType.STRING);
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
            ref FuncType func_type) {
        if (r.type == TokenType.BEGIN) {
            string arg;
            r.nextToken;
            bool not_ended;
            scope (exit) {
                r.valid(r.type == TokenType.END || not_ended, "Expected ended");
                r.nextToken;
            }
            switch (r.token) {
            case "type":
                r.nextToken;
                r.expect(TokenType.WORD);
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
                    r.valid(stage == ParserStage.FUNC, "Only allowed inside a function");

                    if (r.type == TokenType.WORD && r.token.getType is Types.EMPTY) {
                        const label = r.token;
                        r.nextToken;

                        r.expect(TokenType.WORD);
                        func_type.param_names[label] = cast(int) func_type.params.length;
                        const get_type = r.token.getType;
                        func_type.params ~= get_type;
                        r.valid(get_type !is Types.EMPTY, "Illegal type");
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
                r.valid(stage == ParserStage.FUNC, "Result only allowed inside a function declartion");
                r.nextToken;
                while (r.type != TokenType.END) {
                    immutable type = r.token.getType;
                    check(type !is Types.EMPTY, "Data type expected");
                    func_type.results ~= type;
                    r.nextToken;
                }
                return ParserStage.RESULT;
            default:
                not_ended = true;
                r.nextToken;
                return ParserStage.UNDEFINED;
            }
        }
        return ParserStage.UNDEFINED;
    }

    private ParserStage parseFuncBody(
            ref WastTokenizer r,
            const ParserStage stage,
            ref CodeType code_type,
            FuncType func_type) {
        r.valid(stage is ParserStage.FUNC_BODY, "ParserStage should be a function body");
        FunctionContext func_ctx;
        func_ctx.locals = func_type.params;
        func_ctx.local_names = func_type.param_names;
        return parseInstr(r, ParserStage.FUNC_BODY, code_type, func_type, func_ctx);
    }

    private ParserStage parseTypeSection(ref WastTokenizer r, const ParserStage stage) {
        CodeType code_type;
        r.valid(stage < ParserStage.FUNC, "Should been outside function decleration");
        string func_name;
        FuncType func_type;
        func_type.type = Types.FUNC;
        WastTokenizer export_tokenizer;
        scope (exit) {
            __write("func_type %s", func_type);
            //auto type_section = writer.section!(Section.TYPE);
            //const type_idx = cast(int) type_section.sectypes.length;
            //type_section.sectypes ~= func_type;
            const func_idx_ = cast(uint) writer.section!(Section.CODE).sectypes.length;
            const type_idx = writer.createTypeIdx(func_type);
            writer.section!(Section.FUNCTION).sectypes ~= FuncIndex(type_idx);
            writer.section!(Section.CODE).sectypes ~= code_type;
            __write("func_name=%s type_idx=%d func_lookup", func_name, type_idx, func_idx_);
            if (export_tokenizer.isinit) {
                if (func_name) {
                    r.check(!(func_name in func_lookup), format("Export of %s function has already been declared", func_name));
                    func_lookup[func_name] = func_idx_;
                }
            }
            else {
                parseModule(export_tokenizer, ParserStage.FUNC);

                auto export_type = &writer.section!(Section.EXPORT).sectypes[$ - 1];
                __write("export_type %s", *export_type);
                export_type.idx = func_lookup[export_type.name] = func_idx_;
            }
            //writefln("%s code.length=%s %s", Section.CODE, code_type.expr.length, writer.section!(Section.CODE).sectypes.length);
        }

        r.nextToken;
        if (r.BEGIN) {
            export_tokenizer = r.save;
            while (!r.empty && (!r.END)) {
                r.nextToken;
            }
            check(r.END, "End expected");
            r.nextToken;
        }
        else if (r.WORD) {
            func_name = r.token;
            r.nextToken;
        }
        ParserStage arg_stage;
        WastTokenizer rewined;
        uint only_one_type_allowed;
        do {
            rewined = r.save;
            arg_stage = parseFuncArgs(r, ParserStage.FUNC, func_type);

            only_one_type_allowed += (only_one_type_allowed > 0) || (arg_stage == ParserStage.TYPE);
        }
        while ((arg_stage == ParserStage.PARAM) || (only_one_type_allowed == 1));
        if ((arg_stage != ParserStage.TYPE) &&
                (arg_stage != ParserStage.RESULT) ||
                (arg_stage == ParserStage.UNDEFINED)) {
            r = rewined;
        }
        return parseFuncBody(r, ParserStage.FUNC_BODY, code_type, func_type);
        return ParserStage.FUNC;
    }

    private {
        int[string] func_lookup;
    }
    void parse(ref WastTokenizer tokenizer) {
        while (parseModule(tokenizer, ParserStage.BASE) !is ParserStage.END) {
            //empty    
        }
        writeCustomAssert;
    }

}
