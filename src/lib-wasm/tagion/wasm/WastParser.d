module tagion.wasm.WastParser;

import core.exception : RangeError;
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.stdio;
import std.traits;
import std.range;
import std.outbuffer;
import tagion.basic.Debug;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmWriter;
import tagion.wasm.WastAssert;
import tagion.wasm.WastTokenizer;
import tagion.wasm.WasmExpr;
import tagion.wasm.WasmException;
import tagion.wasm.WastKeywords;
import tagion.basic.basic : isinit;
import tagion.utils.convert : convert, tryConvert;

@safe:

Types toType(const(char[]) type_name) pure nothrow @nogc {
    switch (type_name) {
        static foreach (E; EnumMembers!Types) {
            static if (hasUDA!(E, string)) {
                foreach (type_keyword; getUDAs!(E, string)) {
    case type_keyword:
                    return E;
                }
            }
        }
    default:
        return Types.VOID;
    }
    assert(0);
}

unittest {
    assert(toType("i32") is Types.I32);
    assert(toType("bad type") is Types.VOID);
    assert(toType("externref") is Types.EXTERNREF);
}

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
    alias TableType = WasmSection.TableType;
    alias FuncIndex = WasmSection.FuncIndex;
    alias CodeType = WasmSection.CodeType;
    alias DataType = WasmSection.DataType;
    alias ExportType = WasmSection.ExportType;
    alias ElementType = WasmSection.ElementType;
    alias CustomType = WasmSection.Custom;
    alias Limit = WasmSection.Limit;
    enum ParserStage {
        BASE,
        COMMENT,
        ASSERT,
        CONDITIONAL,
        MODULE,
        TYPE,
        FUNC,
        TABLE,
        GLOBAL,
        ELEMENT,
        PARAM,
        RESULT,
        FUNC_BODY,
        CODE,
        // END_FUNC,
        //BREAK,
        EXPORT,
        IMPORT,
        MEMORY,
        EXPECTED,
        ITEM,
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

        uint block_depth_index(string token) const pure {

            try {
                return token.to!uint;
            }
            catch (ConvException e) {
                // Ignore try the label name instead 
            }
            const stack_depth = block_stack.countUntil!(b => b.label == token);
            check(stack_depth >= 0, format("Label %s does not exists", token));
            return cast(uint)(stack_depth);
        }

        Types localType(const int idx) {
            check(idx >= 0 && idx < locals.length, format("Local register index %d is not available", idx));
            return locals[idx];
        }

    }

    static void setLocal(ref WastTokenizer tokenizer, ref FunctionContext func_ctx) {
        auto r = tokenizer.save;
        bool innerLocal() {
            if (r.type is TokenType.BEGIN) {
                r.nextToken;
                if (r.token == "local") {
                    r.nextToken;
                    if (r.token.getType == Types.VOID) {
                        const name = r.token;
                        r.nextToken;
                        const wasm_type = r.token.getType;
                        tokenizer.valid(wasm_type != Types.VOID, format("Invalid type %s", r.token));
                        r.nextToken;
                        func_ctx.local_names[name] = cast(int) func_ctx.locals.length;
                        func_ctx.locals ~= wasm_type;
                    }
                    else {
                        while (r.token.getType != Types.VOID) {
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

    int getGlobal(ref WastTokenizer tokenizer) const {
        int result = global_lookup.get(tokenizer.token, -1);
        if (result < 0) {
            result = tokenizer.token
                .to!int
                .ifThrown!ConvException(-1);
            tokenizer.valid(result >= 0, format("Global register %s not found", tokenizer.token));
        }
        return result;
    }

    private ParserStage parseBodyInstr(
            ref WastTokenizer r,
            const ParserStage stage,
            ref WasmExpr func_wasmexpr, //ref CodeType code_type,
            ref const(FuncType) func_type,
            ref FunctionContext func_ctx) {
        int getLocal(ref WastTokenizer tokenizer) {
            int result = func_ctx.local_names.get(tokenizer.token, -1);
            if (result < 0) {
                result = tokenizer.token
                    .to!int
                    .ifThrown!ConvException(-1);
                tokenizer.valid(result >= 0, format("Local register expected %s not found", tokenizer.token));
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

        int getFuncIdx() {
            int innerFunc(string text) @trusted {
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
                auto export_found = writer.section!(Section.EXPORT)
                    .sectypes
                    .find!(exp => exp.name == r.token.stripQuotes);
                if (!export_found.empty) {
                    return export_found.front.idx;
                }
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
                ParserStage inner_stage) @safe {
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
                if (r.type is TokenType.BEGIN) {
                    auto r_return = r.save;
                    r_return.nextToken;

                    if (r_return.token == "result") {
                        r_return.nextToken;
                        while (r_return.type is TokenType.WORD) {
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

            if (r.type is TokenType.EOF) {
                return inner_stage;
            }
            r.expect(TokenType.BEGIN);
            r.nextToken;
            r.expect(TokenType.WORD);
            const instr = instrWastLookup.get(r.token, illegalInstr);
            auto next_stage = ParserStage.CODE;
            //string label;
            with (IRType) {
                final switch (instr.irtype) {
                case CODE:
                case OP_STACK:
                    r.nextToken;
                    while (r.type is TokenType.BEGIN) {
                        inner_stage = innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    wasmexpr(irLookupTable[instr.name]);
                    break;
                case CODE_EXTEND:
                    r.nextToken;
                    while (r.type is TokenType.BEGIN) {
                        inner_stage = innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    wasmexpr(IR.EXNEND, instr.opcode);
                    break;
                case CODE_TYPE:
                    r.nextToken;
                    auto wasm_results = getReturns(r);
                    if (wasm_results.empty) {
                        wasm_results = block_results;
                    }
                    while (r.type is TokenType.BEGIN) {
                        inner_stage = innerInstr(wasmexpr, r, wasm_results, next_stage);
                    }
                    wasmexpr(irLookupTable[instr.name]);
                    break;
                case RETURN:
                    r.nextToken;
                    while (r.type is TokenType.BEGIN) {
                        inner_stage = innerInstr(wasmexpr, r, func_type.results, next_stage);
                    }
                    wasmexpr(irLookupTable[instr.name]);
                    break;
                case BLOCK_CONDITIONAL:
                    next_stage = ParserStage.CONDITIONAL;
                    goto case;
                case BLOCK:
                    r.nextToken;
                    string label;
                    if (r.type == TokenType.WORD) {
                        label = r.token;
                        r.nextToken;
                    }
                    const wasm_results = getReturns(r);
                    const block_ir = irLookupTable[instr.name];
                    void getArguments() {
                        foreach (n; 0 .. instr.pops.length) {
                            inner_stage = innerInstr(wasmexpr, r, wasm_results, next_stage);
                        }
                    }

                    void addBlockIR() {
                        if (wasm_results.length == 0) {
                            wasmexpr(block_ir, Types.VOID);
                        }
                        else if (wasm_results.length == 1) {
                            wasmexpr(block_ir, wasm_results[0]);
                        }
                        else {
                            auto func_type = FuncType(Types.FUNC, null, wasm_results.idup);
                            const type_idx = writer.createTypeIdx(func_type);
                            wasmexpr(block_ir, type_idx);
                        }
                    }

                    if (block_ir is IR.IF) {
                        getArguments;
                        addBlockIR;
                        func_ctx.block_push(wasm_results, label);

                        if (r.isComponent(PseudoWastInstr.then)) { // (then ... ) 
                            //r.drop(2);
                            r.nextToken;
                            r.nextToken;
                            scope (exit) {
                                r.expect(TokenType.END);
                                r.nextToken;
                            }
                            while (r.type is TokenType.BEGIN) {
                                innerInstr(wasmexpr, r, wasm_results, next_stage);
                            }
                        }
                        if (r.isComponent(instrTable[IR.ELSE].name)) {
                            innerInstr(wasmexpr, r, wasm_results, next_stage);
                        }
                        version (none)
                            if (r.type is TokenType.BEGIN) {
                                auto r_else = r.save;
                                r_else.nextToken;
                                const else_ir = irLookupTable.get(r_else.token, IR.UNREACHABLE);
                                check(else_ir is IR.ELSE,
                                        format("'else' statement expected not '%s' %s",
                                        r_else.token, else_ir));
                                r_else.nextToken;
                                if (r_else.type is TokenType.END) {
                                    r = r_else; /// Empty else '(else)' skip the else IR 
                                }
                                else {
                                    innerInstr(wasmexpr, r, wasm_results, next_stage);
                                }
                            }

                    }
                    else {
                        getArguments;
                        addBlockIR;
                        func_ctx.block_push(wasm_results, label);
                        while (r.type is TokenType.BEGIN) {
                            innerInstr(wasmexpr, r, wasm_results, next_stage);
                        }
                    }
                    func_ctx.block_pop;
                    wasmexpr(IR.END);
                    return stage;
                case BLOCK_ELSE:
                    r.nextToken;
                    wasmexpr(IR.ELSE);
                    while (r.type is TokenType.BEGIN) {
                        innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    return stage;
                case BRANCH:
                    const branch_ir = irLookupTable[instr.name];
                    switch (branch_ir) {
                    case IR.BR:
                        r.nextToken;
                        const blk_idx = func_ctx.block_depth_index(r.token);
                        r.nextToken;
                        while (r.type is TokenType.BEGIN) {
                            inner_stage = innerInstr(wasmexpr, r, block_results, next_stage);
                        }
                        wasmexpr(IR.BR, blk_idx);
                        break;
                    case IR.BR_IF:
                        r.nextToken;
                        const blk_idx = func_ctx.block_depth_index(r.token);
                        r.nextToken;
                        while (r.type is TokenType.BEGIN) {
                            inner_stage = innerInstr(wasmexpr, r, block_results, next_stage);
                        }
                        wasmexpr(IR.BR_IF, blk_idx);
                        break;
                    case IR.BR_TABLE:
                        r.nextToken;

                        const(uint)[] label_idxs;
                        while (r.type is TokenType.WORD) {
                            const block_depth = func_ctx.block_depth_index(r.token);
                            label_idxs ~= block_depth;
                            r.nextToken;
                        }
                        while (r.type is TokenType.BEGIN) {
                            inner_stage = innerInstr(wasmexpr, r, block_results, next_stage);
                        }
                        wasmexpr(IR.BR_TABLE, label_idxs);

                        break;
                    default:
                        assert(0, format("Illegal token %s in %s", r.token, BRANCH));
                    }
                    while (r.type is TokenType.BEGIN) {
                        innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    break;
                case CALL:
                    r.nextToken;
                    const func_idx = getFuncIdx();
                    r.nextToken;
                    while (r.type is TokenType.BEGIN) {
                        inner_stage = innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    wasmexpr(IR.CALL, func_idx);
                    break;
                case CALL_INDIRECT: /// call_indirect tableidx? (type typeidx) ..
                    r.nextToken;
                    uint tableidx;
                    if (r.type is TokenType.WORD) {
                        tableidx = table_lookup.get(r.token, r.token.convert!uint);
                        r.nextToken;
                    }
                    r.expect(TokenType.BEGIN);
                    r.nextToken;
                    uint typeidx;
                    if (r.token == WastKeywords.TYPE) {
                        r.nextToken;
                        typeidx = type_lookup.get(r.token, r.token.convert!uint);
                        r.nextToken;
                        r.expect(TokenType.END);
                        r.nextToken;
                    }
                    while (r.type is TokenType.BEGIN) {
                        inner_stage = innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    wasmexpr(IR.CALL_INDIRECT, typeidx, tableidx);
                    break;
                case LOCAL:
                    r.nextToken;
                    r.expect(TokenType.WORD);
                    const local_idx = getLocal(r);
                    r.nextToken;
                    foreach (i; 0 .. instr.pops.length) {
                        innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    wasmexpr(irLookupTable[instr.name], local_idx);
                    break;
                case GLOBAL:
                    r.nextToken;
                    r.expect(TokenType.WORD);
                    const global_idx = getGlobal(r);
                    r.nextToken;
                    foreach (i; 0 .. instr.pops.length) {
                        innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    wasmexpr(irLookupTable[instr.name], global_idx);
                    break;
                case LOAD:
                case STORE:
                    r.nextToken;
                    uint[2] args; /// Align offset
                    args[0] = instr.opcode;
                    for (uint i = 0; (i < 2) && (r.type is TokenType.WORD); i++) {
                        const param_args = r.token.split("=");
                        r.check(param_args.length == 2, "Expected align=x or offset=x");
                        switch (param_args[0]) {
                        case "align":
                            args[0] = param_args[1].to!uint;
                            break;
                        case "offset":
                            args[1] = param_args[1].to!uint;
                            break;
                        default:
                            r.check(0, format("Illegal parameter %s expected align or offset", param_args[0]));
                        }
                        r.nextToken;
                    }
                    foreach (i; 0 .. instr.pops.length) {
                        innerInstr(wasmexpr, r, block_results, next_stage);
                    }
                    wasmexpr(irLookupTable[instr.name], args[0], args[1]);
                    break;
                case MEMORY:
                    r.nextToken;
                    foreach (i; 0 .. instr.pops.length) {
                        innerInstr(wasmexpr, r, block_results, next_stage);
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
                case REF:
                    r.nextToken;
                    const arg = r.token;
                    r.nextToken;

                    const ir = irLookupTable[instr.name];
                    switch (ir) {
                    case IR.REF_NULL:
                        __write("REF %s %s : %s", ir, arg.toType, arg);
                        if (arg == WastKeywords.EXTERN) {
                            wasmexpr(ir, Types.EXTERNREF);
                        }
                        else if (arg == WastKeywords.FUNC) {
                            wasmexpr(ir, Types.FUNCREF);
                        }
                        else {
                            r.check(0, "Expected arguments extern or func");
                        }

                        break;
                    case IR.REF_IS_NULL:
                        assert(0, "Not implemented yet");
                    case IR.REF_FUNC:
                        assert(0, "Not implemented yet");

                    default:
                        assert(0, "Illegal instructions");
                    }
                    break;
                case ILLEGAL:
                    throw new WasmException(format("Undefined instruction %s", r.token));
                    break;
                case SYMBOL:
                    if (inner_stage == ParserStage.CONDITIONAL) {
                        switch (r.token) {
                        case PseudoWastInstr.then:
                            r.nextToken;
                            if (r.type is TokenType.BEGIN) {
                                inner_stage = innerInstr(wasmexpr, r, block_results, inner_stage);
                            }
                            break;
                        default:
                            check(0, format("Conditional instruction expected not %s", r.token));
                        }

                        return ParserStage.END;
                    }
                    check(0, "Pseudo instruction not allowed");
                }

            }
            return inner_stage;
        }

        setLocal(r, func_ctx);
        return innerInstr(func_wasmexpr, r, func_type.results, stage);

    }

    private void parseInstr(
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
            code_type = CodeType(
                    func_ctx.locals[number_of_func_arguments .. $],
                    code_type.expr ~ func_wasmexpr.serialize);
        }
        scope (exit) {
            if (only(ParserStage.FUNC_BODY, ParserStage.TABLE).canFind(stage)) {
                func_wasmexpr(IR.END);
            }
        }
        if (stage is ParserStage.FUNC_BODY) {
            while (r.type is TokenType.BEGIN) {
                parseBodyInstr(r, stage, func_wasmexpr, func_type, func_ctx);
            }
            return;
        }
        parseBodyInstr(r, stage, func_wasmexpr, func_type, func_ctx);
    }

    static Limit parseLimit(ref WastTokenizer r) {
        Limit limit;
        r.expect(TokenType.WORD);
        const value = r.token.convert!int;
        r.nextToken;
        try {
            limit.to = r.token.convert!int;
            r.nextToken;
            limit.from = value;
            limit.lim = Limits.RANGE;
        }
        catch (ConvException e) {
            limit.from = value;
            limit.lim = Limits.INFINITE;
        }
        return limit;
    }

    unittest {
        {
            auto r = WastTokenizer(" 10 funcref)");
            const limit = parseLimit(r);
            assert(limit is Limit(Limits.INFINITE, 10, 0));
        }
        {
            auto r = WastTokenizer(" 10 100 funcref)");
            const limit = parseLimit(r);
            assert(limit is Limit(Limits.RANGE, 10, 100));
        }
    }

    private ElementType parseElem(ref WastTokenizer r, const ParserStage stage) {
        import tagion.wasm.WastKeywords;

        ElementType elem;
        string elem_name;
        if ((r.type is TokenType.WORD) && !(r.token.isReserved) &&
                (r.token.toType is Types.VOID)) {
            r.nextToken;
            elem_name = r.token;
        }
        string table_name;
        import tagion.wasm.WasmReader : ElementMode;

        bool innerElementType() {
            bool getElementProperty() {
                r.nextToken;
                switch (r.token) {
                case WastKeywords.TABLE: /// (table $x)
                    r.check(elem.mode is ElementMode.PASSIVE,
                            format("Ambiguies element mode %s. Mode has already been defined", elem.mode));
                    r.check(stage !is ParserStage.TABLE,
                            "Table can not be used inside a table");
                    elem.mode = ElementMode.ACTIVE;
                    r.nextToken;
                    if (!table_name) {
                        table_name = r.token;
                        r.nextToken;
                        return true;
                    }
                    r.check(0, "Table has already been defined");
                    break;
                case WastKeywords.OFFSET: /// (offset (..expr..))
                    r.check(elem.mode < ElementMode.DECLARATIVE,
                            format("Ambiguies element mode %s. Mode has already been defined", elem.mode));
                    r.check(elem.expr is null,
                            "Initialisation code has already been defined for this element");
                    elem.mode = ElementMode.ACTIVE;
                    r.nextToken;
                    FuncType void_func;
                    CodeType code_offset;
                    FunctionContext ctx;
                    parseInstr(r, ParserStage.TABLE, code_offset, void_func, ctx);

                    elem.expr = code_offset.expr;
                    return true;
                case WastKeywords.ITEM:
                    r.nextToken;
                    parseElem(r, ParserStage.ITEM);
                    return true;
                default:
                    // empty
                }
                return false;
            }

            auto rewind = r.save;
            if (r.type is TokenType.BEGIN) {
                if (getElementProperty) {
                    r.expect(TokenType.END);
                    r.nextToken;
                    return true;
                }

                r = rewind;
                r.check(elem.expr is null,
                        "Initialisation code has already been defined for this element");
                FuncType void_func;
                CodeType code;
                FunctionContext ctx;
                parseInstr(r, ParserStage.TABLE, code, void_func, ctx);
                elem.expr = code.expr;
                if (elem.expr) {
                    elem.mode = ElementMode.ACTIVE;

                }
                return true;
            }
            return false;
        }

        immutable(uint[]) getFuncs(const Flag!"ignore" flag = No.ignore) {
            immutable(uint)[] result;
            while (r.type is TokenType.WORD) {
                const func_idx = func_lookup.get(r.token, -1);
                if (flag) {
                    if (func_idx < 0) {
                        break;
                    }
                }
                else {
                    r.check(func_idx >= 0, format("Function name %s not defined", r.token));
                }
                result ~= func_idx;
                r.nextToken;
            }
            return result;
        }

        while (r.type !is TokenType.END) {
            switch (r.token) {
            case WastKeywords.FUNCREF: // funcref
                elem.reftype = Types.FUNCREF;
                r.nextToken;
                elem.funcs = getFuncs;
                continue;
            case WastKeywords.FUNC: // func
                r.nextToken;
                elem.funcs = getFuncs;
                continue;
            case WastKeywords.DECLARE:
                elem.mode = ElementMode.DECLARATIVE;
                r.nextToken;
                continue;
            default:
                if (elem.funcs.empty) {
                    elem.funcs = getFuncs(Yes.ignore);
                    if (!elem.funcs.empty) {
                        continue;
                    }
                }
                r.expect(TokenType.BEGIN);
            }
            r.check(innerElementType, "Expression expected");
        }
        return elem;
    }

    struct ForwardElement {
        ElementType elem; /// Element tobe forward parsed
        WastTokenizer tokenizer; /// Cached forward element declaration
    }

    ForwardElement[] forward_elements;
    private void evaluateForwardElements() {
        foreach (ref f; forward_elements) {
            auto r = f.tokenizer;
            if (r.type is TokenType.BEGIN) {
                r.nextToken;
                r.expect(WastKeywords.ELEM);
                r.nextToken;
                while (r.type is TokenType.WORD) {
                    const func_idx = func_lookup.get(r.token, -1);
                    r.check(func_idx >= 0, format("Function %s not defined", r.token));
                    f.elem.funcs ~= func_idx;
                    r.nextToken;

                }
                r.expect(TokenType.END);
                r.nextToken;
            }
            writer.section!(Section.ELEMENT).sectypes ~= f.elem;
        }
    }

    // table  id? reftype  ('elem'|'import'|'export'
    private void parseTable(ref WastTokenizer r) {
        TableType table;
        scope (exit) {
            writer.section!(Section.TABLE).sectypes ~= table;
        }
        ParserStage tableArgument() {
            if (r.type is TokenType.BEGIN) {
                scope (exit) {
                    r.expect(TokenType.END);
                    r.nextToken;
                }
                auto post_r = r;
                r.nextToken;
                r.expect(TokenType.WORD);
                switch (r.token) {
                case WastKeywords.ELEM: // ( elem
                    r.check(only(Types.FUNC, Types.FUNCREF).canFind(table.type),
                            "Missing definition of reftype");
                    r.nextToken;
                    if (r.type is TokenType.BEGIN) { // ( expr )  ...
                        ElementType elem;
                        do {
                            FuncType void_func;
                            CodeType code_elem;
                            FunctionContext ctx;
                            parseInstr(r, ParserStage.ELEMENT, code_elem, void_func, ctx);
                            elem.exprs ~= code_elem.expr;
                            r.check(r.type !is TokenType.EOF, "Declaration is not complete");
                        }
                        while (r.type !is TokenType.BEGIN);
                        elem.tableidx = cast(uint) writer.section!(Section.TABLE).sectypes.length;
                        writer.section!(Section.ELEMENT).sectypes ~= elem;
                    }
                    else { // func ...
                        import tagion.wasm.WasmReader : ElementMode;

                        ForwardElement forward;
                        forward.tokenizer = post_r;
                        int count;
                        while (r.type is TokenType.WORD) {
                            count++;
                            r.nextToken;

                        }
                        table.limit.from = table.limit.to = count;
                        table.limit.lim = Limits.RANGE;
                        forward.elem.mode = ElementMode.ACTIVE;
                        forward.elem.tableidx = cast(uint) writer.section!(Section.TABLE).sectypes.length;
                        {
                            auto out_expr = new OutBuffer;
                            forward.elem.expr = WasmExpr(out_expr)(IR.I32_CONST, 0)(IR.END).serialize;
                        }
                        forward_elements ~= forward;
                    }

                    return ParserStage.ELEMENT;
                case WastKeywords.IMPORT: // ( import
                    r.nextToken;
                    return ParserStage.IMPORT;
                case WastKeywords.EXPORT: // ( export
                    r.nextToken;
                    return ParserStage.EXPORT;
                default:
                    r.check(0, "Syntax error");

                }
            }
            return ParserStage.BASE;
        }

        table.type = toType(r.token);
        if (table.type !is Types.VOID) {
            r.nextToken;
        }
        if (r.type is TokenType.BEGIN) {

            tableArgument;
            return;
        }
        r.expect(TokenType.WORD);
        string table_name;
        if (!r.token.tryConvert!(int).ok) {
            table_name = r.token;
            r.nextToken;
        }
        table.limit = parseLimit(r);
        if (table_name) {
            r.check((table_name in table_lookup) is null,
                    format("Table named %s has already been defined", table_name));
            table_lookup[table_name] = cast(int) writer.section!(Section.TABLE).sectypes.length;

        }
        r.check(table.type.isRefType, format("Ref-type extected not %s", r.token));
        r.nextToken;
    }

    private ParserStage parseGlobal(ref WastTokenizer r) {
        __write("GLOBAL %(%s %)", r.save.map!(t => t.token).take(5));
        if (r.isComponent(WastKeywords.IMPORT)) {
            __write("--- %(%s %)", r.save.map!(t => t.token).take(5));
            parseModule(r, ParserStage.GLOBAL);
            return ParserStage.IMPORT;
        }
        auto type = r.token.toType;
        string label;
        if (type is Types.VOID) {
            label = r.token;
            r.nextToken;
            type = r.token.toType;
        }
        FuncType void_func;
        CodeType code_offset;
        FunctionContext ctx;
        parseInstr(r, ParserStage.GLOBAL, code_offset, void_func, ctx);

        return ParserStage.CODE;
    }

    private void parseImport(ref WastTokenizer r, const ParserStage stage) {
        r.expect(TokenType.BEGIN);
        scope (success) {
            r.expect(TokenType.END);
            r.nextToken;
        }
        r.nextToken;
        r.expect(TokenType.WORD);
        const label = r.token;
        r.nextToken;
        r.expect(TokenType.STRING);
        const arg = r.token;
        r.nextToken;
        r.expect(TokenType.STRING);
        const arg2 = r.token;
        r.nextToken;
        FuncType func_type;
        const ret = parseFuncArgs(r, ParserStage.IMPORT, func_type);
        r.valid(ret == ParserStage.TYPE || ret == ParserStage.PARAM,
                "Import state only allowed inside type or param");

    }

    private ParserStage parseModule(ref WastTokenizer r, const ParserStage stage) {
        if (r.type is TokenType.COMMENT) {
            r.nextToken;
        }
        if (r.type is TokenType.BEGIN) {
            //string label;
            //string arg;
            auto component = r;
            r.nextToken;
            bool not_ended;
            scope (exit) {
                r.valid(r.type is TokenType.END || not_ended, "Missing end");
                if (!not_ended) {
                    r.nextToken;
                }
            }
            switch (r.token) {
            case WastKeywords.MODULE:
                r.valid(stage < ParserStage.MODULE, "Module expected");
                r.nextToken;
                while (r.type is TokenType.BEGIN) {
                    parseModule(r, ParserStage.MODULE);

                }
                return ParserStage.MODULE;
            case WastKeywords.TYPE:
                r.nextToken;
                FuncType func_type;
                parseTypeSection(r, ParserStage.TYPE, func_type);
                return stage;
            case WastKeywords.FUNC: // Example (func $name (param ...) (result i32) )
                parseFuncType(r, stage);
                return ParserStage.FUNC;
            case WastKeywords.RESULT:
                r.valid(only(ParserStage.FUNC).canFind(stage),
                        format("Result only allowed inside function declaration (But was %s)", stage));
                r.nextToken;
                r.expect(TokenType.WORD);
                const arg = r.token;
                r.nextToken;
                return ParserStage.RESULT;
            case WastKeywords.MEMORY:
                MemoryType memory_type;
                scope (exit) {
                    writer.section!(Section.MEMORY).sectypes ~= memory_type;
                }
                r.valid(stage is ParserStage.MODULE, "Memory statement only allowed after memory");
                r.nextToken;
                memory_type.limit = parseLimit(r);
                while (r.type is TokenType.BEGIN) {
                    parseModule(r, ParserStage.MEMORY);
                }
                return ParserStage.MEMORY;
            case WastKeywords.GLOBAL: /// (global label? type|(mut type) expr)
                __write("--> %(%s %)", r.save.map!(t => t.token).take(5));
                r.nextToken;
                GlobalType global_type;
                string label;
                scope (exit) {
                    if (label) {
                        global_lookup[label] = cast(int) writer.section!(Section.GLOBAL).sectypes.length;
                    }
                    writer.section!(Section.GLOBAL).sectypes ~= global_type;
                }
                if (r.type is TokenType.WORD) {
                    global_type.desc.type = r.token.toType;
                    if (global_type.desc.type is Types.VOID) {
                        label = r.token;
                        r.nextToken;
                        if (r.type is TokenType.WORD) {
                            global_type.desc.type = r.token.toType;
                            r.nextToken;
                        }
                    }
                    else {
                        r.nextToken;
                    }
                }
                __write("global_type.desc.type %s", global_type.desc.type);
                __write("Mid %(%s %)", r.save.map!(t => t.token).take(5));
                __write("Mid global_type.desc %s", global_type.desc);
                if ((global_type.desc.type is Types.VOID) && r.isComponent("mut")) {
                    global_type.desc.mut = Mutable.VAR;
                    r.nextToken;
                    r.nextToken;
                    global_type.desc.type = r.token.toType;
                    r.nextToken;
                    r.expect(TokenType.END);
                    r.nextToken;
                    __write("MUT After %(%s %)", r.save.map!(t => t.token).take(5));
                }
                __write("global_type.desc %s", global_type.desc);
                __write("After %(%s %)", r.save.map!(t => t.token).take(5));
                FuncType func_type;
                CodeType code_global;
                FunctionContext func_ctx;
                parseInstr(r, ParserStage.GLOBAL, code_global, func_type, func_ctx);
                global_type.expr = code_global.expr ~ IR.END;
                __write("global_type %s", global_type);
                return ParserStage.GLOBAL;
            case WastKeywords.SEGMENT:
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
            case WastKeywords.EXPORT:
                ExportType export_type;
                scope (exit) {
                    writer.section!(Section.EXPORT).sectypes ~= export_type;
                }
                r.valid(stage == ParserStage.MODULE || stage == ParserStage.FUNC,
                        "Function or module stage expected");

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
            case WastKeywords.IMPORT:
                parseImport(component, ParserStage.MODULE);
                r = component;
                not_ended = true;
                return stage;
            case WastKeywords.TABLE:
                r.nextToken;
                parseTable(r);
                return stage;
            case WastKeywords.ELEM:
                r.nextToken;
                writer.section!(Section.ELEMENT).sectypes ~= parseElem(r, ParserStage.ELEMENT);
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
                while (r.type is TokenType.BEGIN) {
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
                const label = r.token;
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
                const arg = r.token;
                r.nextToken;
                return ParserStage.ASSERT;
            default:
                if (r.type is TokenType.COMMENT) {
                    r.nextToken;
                    return ParserStage.COMMENT;
                }
                not_ended = true;
                r.nextToken;
                return ParserStage.UNDEFINED;
            }
        }
        if (r.type is TokenType.COMMENT) {
            r.nextToken;
        }
        return ParserStage.END;
    }

    private ParserStage parseFuncArgs(
            ref WastTokenizer r,
            const ParserStage stage,
            ref FuncType func_type) {
        // ( type|param|result... )
        if (r.type is TokenType.BEGIN) {
            auto rewind = r;
            r.nextToken;
            bool not_ended;
            scope (success) {
                r.valid(r.type == TokenType.END || not_ended,
                        format("Expected ended on %s", r.token));
                if (!not_ended) {
                    r.nextToken;
                }
            }
            switch (r.token) {
            case WastKeywords.TYPE:
                r.check(stage !is ParserStage.TYPE, format("Type can not be declared inside a type"));
                r.nextToken;
                r.expect(TokenType.WORD);
                const type_idx = type_lookup.get(r.token, -1);

                r.check(type_idx >= 0, format("Type named %s not found", r.token));
                func_type = writer.section!(Section.TYPE).sectypes[type_idx];
                r.nextToken;
                return ParserStage.TYPE;
            case WastKeywords.PARAM: // Example (param $y i32)
                r.nextToken;
                if (stage is ParserStage.IMPORT) {
                    while (r.token.getType !is Types.VOID) {
                        func_type.params ~= r.token.getType;
                        r.nextToken;
                    }
                }
                else {
                    r.valid(only(ParserStage.FUNC, ParserStage.TYPE).canFind(stage),
                            format("Only allowed inside a function (But is %s)", stage));

                    if (r.type is TokenType.WORD && r.token.getType is Types.VOID) {
                        const label = r.token;
                        r.nextToken;

                        r.expect(TokenType.WORD);
                        func_type.param_names[label] = cast(int) func_type.params.length;
                        const get_type = r.token.getType;
                        func_type.params ~= get_type;
                        r.valid(get_type !is Types.VOID, "Illegal type");
                        r.nextToken;
                    }
                    while (r.type is TokenType.WORD && r.token.getType !is Types.VOID) {
                        func_type.params ~= r.token.getType;
                        //arg = r.token;
                        r.nextToken;
                    }
                }
                return ParserStage.PARAM;
            case WastKeywords.RESULT: // Example (result f32)
                r.valid(only(ParserStage.FUNC, ParserStage.TYPE).canFind(stage),
                        format("Result only allowed inside a function declaration (But is %s)", stage));
                r.nextToken;
                while (r.type !is TokenType.END) {
                    immutable type = r.token.getType;
                    check(type !is Types.VOID, "Data type expected");
                    func_type.results ~= type;
                    r.nextToken;
                }
                return ParserStage.RESULT;
            case WastKeywords.EXPORT: // Ignore (export "<name>") 
                r.check(stage is ParserStage.FUNC, "'export' not expected here");
                r = rewind;
                not_ended = true;
                return ParserStage.EXPORT;
            default:
                not_ended = true;
                r.nextToken;
            }
        }
        return ParserStage.UNDEFINED;
    }

    private void parseFuncBody(
            ref WastTokenizer r,
            const ParserStage stage,
            ref CodeType code_type,
            FuncType func_type) {
        r.valid(stage is ParserStage.FUNC_BODY, "ParserStage should be a function body");
        FunctionContext func_ctx;
        func_ctx.locals = func_type.params;
        func_ctx.local_names = func_type.param_names;
        parseInstr(r, ParserStage.FUNC_BODY, code_type, func_type, func_ctx);
    }

    private void parseTypeSection(ref WastTokenizer r, const ParserStage stage, ref FuncType func_type) {
        string type_name;
        if (r.type is TokenType.WORD) {
            type_name = r.token;
            r.nextToken;
        }
        r.expect(TokenType.BEGIN);
        r.nextToken;
        r.expect(TokenType.WORD);
        switch (r.token) {
        case WastKeywords.FUNC:
            r.nextToken;
            ParserStage func_stage = parseFuncArgs(r, stage, func_type); // ( param ... )
            //r.check(only(ParserStage.PARAM, ParserStage.RESULT, ParserStage.UNDEFINED).canFind(func_stage), format("Param or result expected but got %s", func_stage));
            if (func_stage is ParserStage.PARAM) {
                parseFuncArgs(r, stage, func_type); // ( result ... )
            }
            const type_idx = writer.createTypeIdx(func_type);
            if (type_name) {
                check((type_name in type_lookup) is null,
                        format("Type name %s already defined", type_name));
                type_lookup[type_name] = type_idx;
            }
            break;
        default:
            r.check(0, format("Type expected not %s", r.token));
        }
        r.expect(TokenType.END);
        r.nextToken;

    }

    unittest {
        const text = "( func (param i32) (result f32) )";
        {
            auto w = new WasmWriter;
            auto wast = new WastParser(w);
            auto r = WastTokenizer(text);
            FuncType func_type;
            wast.parseTypeSection(r, ParserStage.FUNC, func_type);
            assert(equal(func_type.params, [Types.I32]));
            assert(equal(func_type.results, [Types.F32]));
        }
    }

    private void parseFuncType(ref WastTokenizer r, const ParserStage stage) {
        static void innerParseExport(ref WastTokenizer r, ref ExportType export_type) {
            if (r.type is TokenType.BEGIN) {
                auto rewind = r.save;
                r.nextToken;
                if (r.token == WastKeywords.EXPORT) {
                    r.check(export_type == ExportType.init,
                            "Export has already been defined");
                    r.nextToken;
                    r.check(r.type is TokenType.STRING,
                            "Name of export expected");
                    export_type.name = r.token.stripQuotes;
                    export_type.idx = -1; // Should be set when the function index is know
                    export_type.desc = IndexType.FUNC;
                    r.nextToken;
                    r.expect(TokenType.END);
                    r.nextToken;
                    return;
                }
                r = rewind;
            }
        }

        CodeType code_type;
        r.valid(stage < ParserStage.FUNC, "Should been outside function declaration");
        string func_name;
        FuncType func_type;
        func_type.type = Types.FUNC;
        WastTokenizer export_tokenizer;
        scope (exit) {
            const func_idx = cast(uint) writer.section!(Section.CODE).sectypes.length;
            const type_idx = writer.createTypeIdx(func_type);
            writer.section!(Section.FUNCTION).sectypes ~= FuncIndex(type_idx);
            writer.section!(Section.CODE).sectypes ~= code_type;
            if (export_tokenizer.isinit) {
                if (func_name) {
                    r.check(!(func_name in func_lookup),
                            format("Export of %s function has already been declared", func_name));
                    func_lookup[func_name] = func_idx;
                }
            }
            else {
                parseModule(export_tokenizer, ParserStage.FUNC);
                auto export_type = &writer.section!(Section.EXPORT).sectypes[$ - 1];
                if (!func_name) {
                    func_name = export_type.name;
                }
                export_type.idx = func_lookup[func_name] = func_idx;
            }
        }
        r.nextToken;
        if (r.isComponent(WastKeywords.EXPORT)) {
            //if (r.type is TokenType.BEGIN) {
            export_tokenizer = r.save;
            r.nextBlock;
        }
        else if (r.type is TokenType.WORD) {
            func_name = r.token;
            r.nextToken;
        }
        if (export_tokenizer.isinit && r.isComponent(WastKeywords.EXPORT)) {
            export_tokenizer = r.save;
            r.nextBlock;
        }
        ParserStage arg_stage;
        WastTokenizer rewind;
        uint only_one_type_allowed;

        do {
            rewind = r;
            arg_stage = parseFuncArgs(r, ParserStage.FUNC, func_type);
            only_one_type_allowed += (only_one_type_allowed > 0) || (arg_stage == ParserStage.TYPE);
        }
        while (only(ParserStage.PARAM, ParserStage.EXPORT).canFind(arg_stage) || (only_one_type_allowed == 1));
        if ((arg_stage != ParserStage.TYPE) &&
                (arg_stage != ParserStage.RESULT) ||
                (arg_stage == ParserStage.UNDEFINED)) {
            r = rewind;
        }
        parseFuncBody(r, ParserStage.FUNC_BODY, code_type, func_type);
    }

    private {
        int[string] func_lookup; /// Code section name lookup table
        int[string] type_lookup; /// Type section name lookup table
        int[string] table_lookup; /// Table section name lookup table
        int[string] global_lookup; /// Global section name lookup table
    }
    void parse(ref WastTokenizer tokenizer) {
        while (parseModule(tokenizer, ParserStage.BASE) !is ParserStage.END) {
            //empty    
        }
        evaluateForwardElements();
        writeCustomAssert;
        forward_elements = null;
    }

}
