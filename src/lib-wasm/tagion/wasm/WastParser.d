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
import tagion.wasm.WasmException;
import tagion.wasm.WasmWriter;
import tagion.wasm.WastAssert;
import tagion.wasm.WastTokenizer;
import tagion.basic.basic : isinit;

@safe:

class WastParserException : WasmException {
    WastTokenizer tokenizer;
    this(string msg,
            ref WastTokenizer tokenizer,
            string file = __FILE__,
            size_t line = __LINE__) pure nothrow {
        this.tokenizer = tokenizer;
        super(msg, file, line);
    }
}

struct WastParser {
    WasmWriter writer;
    SectionAssert wast_assert;
    private void writeCustomAssert() {
        if (wast_assert !is SectionAssert.init) {
            auto _custom = new CustomType("assert", wast_assert.toDoc);
            writer.mod[Section.CUSTOM].list[Section.DATA] ~= _custom;
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
    alias TypeIndex = WasmSection.TypeIndex;
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
        int[string] params; /// Parameter names
        Block[] block_stack;
        const(Types)[] stack;
        int blk_idx;

        void push(const Types t) pure nothrow {
            stack ~= t;
        }

        void push(const(Types[]) t) pure nothrow {
            stack ~= t;
        }

        Types pop() pure {
            if (stack.length == 0) {
                throw new WasmException("Stack empty");
            }
            scope (exit) {
                stack.length--;
            }
            return stack[$ - 1];
        }

        Types peek(const int idx = 0) const pure {
            if ((idx >= stack.length) || (idx < 0)) {
                throw new WasmException("Stack empty");
            }
            return stack[$ - idx - 1];
        }

        void drop(const size_t n) pure {
            if (stack.length < n) {
                throw new WasmException("Stack underflow");
            }
            stack.length -= n;
        }

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
    }

    private ParserStage parseInstr(
            ref WastTokenizer r,
            const ParserStage stage,
            ref CodeType code_type,
            ref const(FuncType) func_type,
            ref FunctionContext func_ctx) {
        import tagion.wasm.WasmExpr;

        bool got_error;
        scope (exit) {
            if (got_error) {
                r.dropScopes;
            }
        }
        void parser_check(ref const(WastTokenizer) tokenizer,
                const bool flag,
                string msg = null,
                string file = __FILE__,
                const size_t code_line = __LINE__) nothrow {
            got_error |= tokenizer.check(flag, msg, file, code_line);
            //ignore_error=(r.type != TokenType.BEGIN) && flag;
        }

        static WasmExpr createWasmExpr() {
            import std.outbuffer;

            auto bout = new OutBuffer;
            return WasmExpr(bout);
        }

        immutable number_of_func_arguments = func_type.params.length;
        scope immutable(Types)[] locals = func_type.params;
        int getLocal(ref const(WastTokenizer) tokenizer) @trusted {
            int result = func_ctx.params[tokenizer.token].ifThrown!RangeError(int(-1));
            if (result < 0) {
                result = tokenizer.token
                    .to!int
                    .ifThrown!ConvException(-1);
                tokenizer.check(result >= 0, "Local register expected");
            }
            return result;
        }

        Types getLocalType(const int idx) {
            check(idx >= 0 && idx < locals.length, format("Local register index %d is not available", idx));

            return locals[idx];
        }

        int getFuncIdx() @trusted {
            int innerFunc(string text) {
                int result = func_idx[text].ifThrown!RangeError(int(-1));
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
                if (writer.mod[Section.EXPORT]!is null) {
                    auto export_found = writer.mod[Section.EXPORT].sectypes
                        .find!(exp => exp.name == r.token.stripQuotes);
                    if (!export_found.empty) {
                        return export_found.front.idx;
                    }
                }

                break;
            default:
                // empty
            }
            parser_check(r, 0, format("Export %s is not defined", r.token));

            return -1;
        }

        auto func_wasmexpr = createWasmExpr;
        ParserStage innerInstr(ref WasmExpr wasmexpr,
                ref WastTokenizer r,
                const(Types[]) block_results,
        ParserStage instr_stage) @safe nothrow {
            try {
                static const(Types)[] getReturns(ref WastTokenizer r) @safe nothrow {
                    Types[] results;
                    if (r.type == TokenType.BEGIN) {
                        auto r_return = r.save;
                        r_return.nextToken;

                        if (r_return.token == "result") {
                            r_return.nextToken;
                            while (r_return.type == TokenType.WORD) {
                                r_return.check(r_return.type == TokenType.WORD);
                                results ~= r_return.token.getType;
                                r_return.nextToken;
                            }
                            r_return.check(r_return.type == TokenType.END);
                            r_return.nextToken;
                            r = r_return;
                        }
                    }
                    return results;
                }

                r.expect(TokenType.BEGIN);
                scope (exit) {
                    r.expect(TokenType.END, "Expect an end ')'");
                    r.nextToken;
                    if (func_wasmexpr != wasmexpr) {
                        func_wasmexpr.append(wasmexpr);
                    }
                }
                r.nextToken;
                r.expect(TokenType.WORD);
                const instr = instrWastLookup.get(r.token, illegalInstr);
                string label;
                with (IRType) {
                    final switch (instr.irtype) {
                    case CODE:
                        r.nextToken;
                        const sp = func_ctx.stack.length;

                        while (sp + instr.pops.length > func_ctx.stack.length) {
                            innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                        }
                        parser_check(r, instr.pops == func_ctx.stack[sp .. $],
                        format("Type mismatch %s %s", instr.pops, func_ctx.stack[sp .. $]));
                        func_ctx.drop(instr.pops.length);
                        func_ctx.push(instr.pushs);
                        wasmexpr(irLookupTable[instr.name]);
                        break;
                    case CODE_EXTEND:
                        r.nextToken;
                        const sp = func_ctx.stack.length;

                        while (sp + instr.pops.length > func_ctx.stack.length) {
                            innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                        }
                        func_ctx.push(instr.pushs);
                        wasmexpr(IR.EXNEND, instr.opcode);
                        break;
                    case CODE_TYPE:
                        r.nextToken;
                        auto wasm_results = getReturns(r);
                        if (wasm_results.empty) {
                            wasm_results = block_results;
                        }
                        const sp = func_ctx.stack.length;
                        bool breakout;
                        while (r.type == TokenType.BEGIN) {
                            const sub_stage = innerInstr(wasmexpr, r, wasm_results, ParserStage.CODE);
                            breakout |= (sub_stage == ParserStage.END);
                        }
                        if (!breakout) {
                            func_ctx.drop(instr.pops.length);
                        }
                        func_ctx.push(instr.pushs);
                        wasmexpr(irLookupTable[instr.name]);
                        break;
                    case RETURN:
                        r.nextToken;
                        const sp = func_ctx.stack.length;
                        while (sp + func_type.results.length > func_ctx.stack.length) {
                            innerInstr(wasmexpr, r, func_type.results, ParserStage.CODE);
                        }
                        func_ctx.drop(func_type.results.length);
                        wasmexpr(irLookupTable[instr.name]);
                        break;
                    case BLOCK:
                        writefln("Block %s", r);
                        r.nextToken;
                        label = null;
                        if (r.type == TokenType.WORD) {
                            label = r.token;
                            r.nextToken;
                        }
                        scope (success) {
                            func_ctx.block_pop;
                        }
                        const wasm_results = getReturns(r);
                        writefln("  Results %s", wasm_results);
                        if (wasm_results.length == 0) {
                            writefln("No result args");
                            wasmexpr(irLookupTable[instr.name]);
                        }
                        else if (wasm_results.length == 1) {
                            wasmexpr(irLookupTable[instr.name], wasm_results[0]);
                        }
                        else {
                            wasmexpr(irLookupTable[instr.name], 42);
                        }
                        writefln("Before block push %s", wasm_results);
                        func_ctx.block_push(wasm_results, label);
                        while (r.type == TokenType.BEGIN) {
                            innerInstr(wasmexpr, r, wasm_results, ParserStage.CODE);
                        }

                        return stage;
                    case BRANCH:
                        writefln("IR.BR %s token=%s", getInstr!(IR.BR), r);
                        switch (r.token) {
                        case getInstr!(IR.BR).wast:
                            r.nextToken;
                            writefln("BR index %s", r);
                            const blk = func_ctx.block_peek(r.token);
                            r.nextToken;
                            const sp = func_ctx.stack.length;
                            while (r.type == TokenType.BEGIN) {
                                writefln(" == %s sp=%d size=%d blk=%d block_results=%d", r.token, sp, func_ctx.stack
                                        .length, blk.types.length, block_results.length);
                                innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                            }
                            writefln("Branch %s %s ", blk, r);
                            const number_of_args = func_ctx.stack.length - sp;
                            check(block_results.length == number_of_args,
                                    format("Branch expect %-(%s %) but got %s arguments", block_results
                                    .map!(t => typesName(t)), number_of_args));
                            wasmexpr(IR.BR, blk.idx);
                            instr_stage = ParserStage.END;
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
                        const idx = getFuncIdx();
                        label = r.token;
                        r.nextToken;
                        while (r.type == TokenType.BEGIN) {
                            innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                        }
                        wasmexpr(IR.CALL, idx);
                        break;
                    case CALL_INDIRECT:
                        break;
                    case LOCAL:
                        r.nextToken;
                        label = r.token;
                        r.expect(TokenType.WORD);
                        const local_idx = getLocal(r);
                        wasmexpr(irLookupTable[instr.name], local_idx);
                        writefln("local_idx=%d", local_idx);
                        const local_type = getLocalType(local_idx);
                        r.nextToken;
                        writefln("POPS %s", instr.pops);
                        foreach (i; 0 .. instr.pops.length) {
                            innerInstr(wasmexpr, r, block_results, ParserStage.CODE);
                        }
                        if (instr.pushs.length) {
                            func_ctx.push(local_type);
                        }
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
                            func_ctx.push(Types.I32);
                            wasmexpr(ir, r.get!int);
                            break;
                        case I64_CONST:
                            func_ctx.push(Types.I64);
                            wasmexpr(ir, r.get!long);
                            break;
                        case F32_CONST:
                            func_ctx.push(Types.F32);
                            wasmexpr(ir, r.get!float);
                            break;
                        case F64_CONST:
                            func_ctx.push(Types.F64);
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
                        __write("SYMBOL %s %s", r.token, r.type);
                        r.nextToken;
                        __write("LABEL %s %s", r.token, r.type);
                        __write("instr %s", instr);
                        __write("instr.pushs %s instr.pops %s", instr.pushs, instr.pops);
                        string[] labels;
                        while (r.type == TokenType.WORD) {
                            labels ~= r.token;
                            r.nextToken;
                        }
                        for (uint i = 0; (instr.pops.length == 0) ? r.type == TokenType.BEGIN : i < instr.pops.length; i++) {
                            innerInstr(wasmexpr, r, block_results, ParserStage.CODE);

                        }
                        switch (instr.wast) {
                        case PseudoWastInstr.local:
                            __write("labels %s", labels);
                            if ((labels.length == 2) && (labels[1].getType !is Types.EMPTY)) {
                                func_ctx.params[labels[0]] = cast(int) locals.length;
                                locals ~= labels[1].getType;
                                break;
                            }
                            locals ~= labels.map!(l => l.getType).array;
                            break;
                        default:
                            // Empty
                        }
                    }
                }
            }
            catch (Exception e) {
                r.error(e);
                r.dropScopes;
            }
            return instr_stage;
        }

        scope (exit) {
            code_type = CodeType(locals[number_of_func_arguments .. $], func_wasmexpr.serialize);
        }
        return innerInstr(func_wasmexpr, r, func_type.results, stage);

    }

    private ParserStage parseModule(ref WastTokenizer r, const ParserStage stage) {
        if (r.type == TokenType.COMMENT) {
            r.nextToken;
        }
        if (r.type == TokenType.BEGIN) {
            string label;
            string arg;
            Types[] result_types;
            r.nextToken;
            bool not_ended;
            scope (exit) {
                r.check(r.type == TokenType.END || not_ended, "Missing end");
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
                writefln("Result %d:%s token %s", r.line, r.getLine, r);
                version (none) {
                    result_types = null;
                    for (r.nextToken; r.type != TokenType.END; r.nextToken) {
                        arg = r.token; /// Should be removed (now result_types is used instead)
                        result_types ~= r.token.getType;
                    }
                    //r.nextToken;
                }
                r.nextToken;
                r.check(r.type == TokenType.WORD);
                arg = r.token;
                r.nextToken;
                return ParserStage.RESULT;
            case "memory":
                MemoryType memory_type;
                scope (exit) {
                    writer.section!(Section.MEMORY).sectypes ~= memory_type;
                }
                r.check(stage == ParserStage.MODULE);
                r.nextToken;
                r.check(r.type == TokenType.WORD);
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
                r.check(stage == ParserStage.MEMORY);
                r.nextToken;
                r.check(r.type == TokenType.WORD);
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
                r.check(stage == ParserStage.MODULE || stage == ParserStage.FUNC);

                r.nextToken;
                r.check(r.type == TokenType.STRING);
                export_type.name = r.token.stripQuotes;
                if (stage != ParserStage.FUNC) {
                    r.nextToken;
                    r.check(r.type == TokenType.WORD);
                    export_type.idx = func_idx.get(r.token, -1);
                }
                export_type.desc = IndexType.FUNC;
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
                FunctionContext func_ctx;
                //scope int[string] params;
                const ret = parseFuncArgs(r, ParserStage.IMPORT, func_type, func_ctx);
                r.check(ret == ParserStage.TYPE || ret == ParserStage.PARAM);

                return stage;
            case "assert_return_nan":
            case "assert_return":
                r.check(stage == ParserStage.BASE);
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
                //scope int[string] params;
                // Invoke call
                parseInstr(r, ParserStage.ASSERT, code_invoke, func_type, func_ctx);
                while (r.type == TokenType.BEGIN) {
                    parseInstr(r, ParserStage.EXPECTED, code_result, func_type, func_ctx);
                }
                writefln("func_ctx.stack=%s", func_ctx.stack);
                assert_type.results = func_ctx.stack;
                assert_type.invoke = code_invoke.serialize;
                assert_type.result = code_result.serialize;
                wast_assert.asserts ~= assert_type;
                return ParserStage.ASSERT;
            case "assert_trap":
                r.check(stage == ParserStage.BASE);
                Assert assert_type;
                assert_type.method = Assert.Method.Trap;
                assert_type.name = r.token;
                label = r.token;
                r.nextToken;
                FuncType func_type;
                CodeType code_invoke;
                FunctionContext func_ctx;
                //scope int[string] params;
                // Invoke call
                parseInstr(r, ParserStage.ASSERT, code_invoke, func_type, func_ctx);
                assert_type.invoke = code_invoke.serialize;

                r.check(r.type == TokenType.STRING);
                assert_type.message = r.token;
                wast_assert.asserts ~= assert_type;
                r.nextToken;
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
            ref scope FunctionContext func_ctx) {
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
                        func_ctx.params[label] = cast(int) func_type.params.length;
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
                writefln("2. Result %d:%s token %s", r.line, r.getLine, r);
                r.check(stage == ParserStage.FUNC);
                r.nextToken;
                while (r.type != TokenType.END) {
                    immutable type = r.token.getType;
                    check(type !is Types.EMPTY, "Data type expected");
                    func_type.results ~= type;
                    r.nextToken;
                }
                //r.check(r.type == TokenType.WORD);

                //arg = r.token;
                //func_type.results = [r.token.getType];
                //r.check(r.token.getType !is Types.EMPTY);
                //r.nextToken;
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
        CodeType code_type;
        r.check(stage < ParserStage.FUNC);
        auto type_section = writer.section!(Section.TYPE);

        const type_idx = cast(int) type_section.sectypes.length;
        //writeln("Function code");
        WastTokenizer export_tokenizer;
        scope (exit) {
            if (!export_tokenizer.isinit) {
                parseModule(export_tokenizer, ParserStage.FUNC);

                auto export_type = &writer.section!(Section.EXPORT).sectypes[$ - 1];
                export_type.idx = func_idx[export_type.name] = type_idx;
            }
            const type_index = cast(uint) writer.section!(Section.CODE).sectypes.length;
            writer.section!(Section.FUNCTION).sectypes ~= TypeIndex(type_index);
            writer.section!(Section.CODE).sectypes ~= code_type;
            //writefln("%s code.length=%s %s", Section.CODE, code_type.expr.length, writer.section!(Section.CODE).sectypes.length);
        }

        FuncType func_type;
        func_type.type = Types.FUNC;
        FunctionContext func_ctx;
        //scope Types[] locals;
        scope (exit) {
            type_section.sectypes ~= func_type;
        }

        r.nextToken;
        if (r.type == TokenType.BEGIN) {
            export_tokenizer = r.save;
            while (!r.empty && (r.type != TokenType.END)) {
                r.nextToken;
            }
            check(r.type == TokenType.END, "End expected");
            r.nextToken;
        }
        else if (r.type == TokenType.WORD) {
            func_idx[r.token] = type_idx;
            r.nextToken;
        }
        ParserStage arg_stage;
        WastTokenizer rewined;
        uint only_one_type_allowed;
        do {
            rewined = r.save;
            arg_stage = parseFuncArgs(r, ParserStage.FUNC, func_type, func_ctx);

            only_one_type_allowed += (only_one_type_allowed > 0) || (arg_stage == ParserStage.TYPE);
        }
        while ((arg_stage == ParserStage.PARAM) || (only_one_type_allowed == 1));
        //auto result_r=r.save;
        if (arg_stage != ParserStage.TYPE && arg_stage != ParserStage.RESULT ||
                arg_stage == ParserStage.UNDEFINED) {
            r = rewined;
        }
        while (r.type == TokenType.BEGIN) {
            const ret = parseInstr(r, ParserStage.FUNC_BODY, code_type, func_type, func_ctx);
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
        writeCustomAssert;
    }

}

version (WAST) @safe
unittest {
    import std.file : readText;
    import std.stdio;
    import tagion.basic.basic : unitfile;

    immutable wast_test_files = [
        "i32.wast",
        /*
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
*/
    ];
    version (none) immutable wast_test_files = [
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
    ];
    import std.file : fwrite = write;

    foreach (wast_file; wast_test_files) {
        immutable wast_text = wast_file.unitfile.readText;
        auto tokenizer = WastTokenizer(wast_text);
        auto writer = new WasmWriter;
        auto wast_parser = WastParser(writer);
        wast_parser.parse(tokenizer);
        if (wast_file == "i32.wast") {
            "/tmp/i32.wasm".fwrite(writer.serialize);
        }
    }

}
