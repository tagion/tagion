module tagion.wasm.WasmBetterC;

import tagion.basic.Debug;

import std.algorithm;
import std.array;
import std.array;
import std.conv : to;
import std.format;
import std.range;
import std.range.primitives : isOutputRange;
import std.stdio;
import std.traits : ConstOf, EnumMembers, ForeachType, PointerTarget, isFloatingPoint;
import std.typecons : Tuple;
import std.typecons;
import std.uni : toLower;
import tagion.errors.tagionexceptions;
import tagion.hibon.Document;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmException;
import tagion.wasm.WasmReader;
import tagion.wasm.WastAssert;

@safe class WasmBetterCException : WasmException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!WasmBetterCException;

@safe WasmBetterC!(Output) wasmBetterC(Output)(WasmReader wasmreader, Output output) {
    return new WasmBetterC!(Output)(wasmreader, output);
}

@safe class WasmBetterC(Output) : WasmReader.InterfaceModule {
    alias Sections = WasmReader.Sections;
    //alias ExprRange=WasmReader.WasmRange.WasmSection.ExprRange;
    //alias WasmArg=WasmReader.WasmRange.WasmSection.WasmArg;
    alias ImportType = WasmReader.WasmRange.WasmSection.ImportType;
    alias ExportType = WasmReader.WasmRange.WasmSection.ExportType;
    alias FuncType = WasmReader.WasmRange.WasmSection.FuncType;
    alias TypeIndex = WasmReader.WasmRange.WasmSection.TypeIndex;
    alias CodeType = WasmReader.WasmRange.WasmSection.CodeType;

    alias Limit = WasmReader.Limit;
    alias GlobalDesc = WasmReader.WasmRange.WasmSection.ImportType.ImportDesc.GlobalDesc;

    protected {
        Output output;
        WasmReader wasmstream;
        string indent;
        string spacer;
    }

    string module_name;
    string[] imports;
    string[] attributes;
    this(WasmReader wasmstream, Output output, string spacer = "    ") {
        this.output = output;
        this.wasmstream = wasmstream;
        this.spacer = spacer;
    }

    static string limitToString(ref const Limit limit) {
        immutable to_range = (limit.lim is Limits.INFINITE) ? "" : format(" %d", limit.to);
        return format("%d%s", limit.from, to_range);
    }

    static string globalToString(ref const GlobalDesc globaldesc) {
        with (Mutable) {
            final switch (globaldesc.mut) {
            case CONST:
                return format("%s", typesName(globaldesc.type));
            case VAR:
                return format("(mut %s)", typesName(globaldesc.type));
            }
        }
        assert(0);
    }

    static string offsetAlignToString(const(WasmArg[]) wargs)
    in {
        assert(wargs.length == 2);
    }
    do {
        string result;
        const _offset = wargs[1].get!uint;
        const _align = wargs[0].get!uint;

        if (_offset > 0) {
            result ~= format(" offset=%d", _offset);
        }
        if (_align > 0) {
            result ~= format(" align=%d", _align);
        }
        return result;
    }

    void produceAsserts(const Document doc, const string indent) {
        const sec_assert = SectionAssert(doc);
        void innerAssert(const Assert _assert, const string indent) {
            Context ctx;
            const(FuncType) func_void;
            auto code_type = CodeType(_assert.invoke);
            auto invoke_expr = code_type[];
            output.writefln("%s// expr   %(%02X %)", indent, _assert.invoke);
            output.writefln("%s// result %(%02X %)", indent, _assert.result);
            with (Assert.Method) final switch (_assert.method) {
            case Trap:
                void assert_block(const string _indent) {
                    block(invoke_expr, func_void, ctx, _indent ~ spacer);
                    output.writefln("%s}", _indent);
                }

                output.writefln("%serror.assert_trap((() {", indent);
                assert_block(indent ~ spacer);
                output.writefln("%s)());", indent);

                break;
            case Return_nan:
                block(invoke_expr, func_void, ctx, indent, true);
                auto result_type = CodeType(_assert.result);
                auto result_expr = result_type[];
                block(result_expr, func_void, ctx, indent, true);
                output.writef(`%1$sassert(math.isnan(%2$s)`, indent, ctx.pop);
                if (_assert.message.length) {
                    output.writef(`, "%s"`, _assert.message);
                }
                output.writeln(");");
                break;
            case Return, Invalid:
                block(invoke_expr, func_void, ctx, indent, true);
                auto result_type = CodeType(_assert.result);
                auto result_expr = result_type[];
                Context ctx_results;
                block(result_expr, func_void, ctx_results, indent, true);

                output.writef("%sassert(%s is %s", indent, ctx.pop, ctx_results.pop);
                if (_assert.message.length) {
                    output.writef(`, "%s"`, _assert.message);
                }
                output.writeln(");");
            }
        }

        foreach (_assert; sec_assert.asserts) {
            output.writefln("%s{ // %s", indent, _assert.name);
            innerAssert(_assert, indent ~ spacer);
            output.writefln("%s}", indent);

        }
    }

    enum max_linewidth = 120;
    alias Custom = Sections[Section.CUSTOM];
    void custom_sec(ref scope const(Custom) _custom) {
        import tagion.hibon.HiBONJSON;

        //output.writef(`%s(custom "%s" "`, indent, _custom.name);
        enum {
            SPACE = 32,
            DEL = 127
        }
        if (_custom.doc.isInorder) {
            switch (_custom.name) {
            case "assert":
                output.writeln("@safe");
                output.writefln("%sunittest { // %s", indent, _custom.name);
                produceAsserts(_custom.doc, indent ~ spacer);
                output.writefln("%s}", indent);
                break;
            default:
                output.writefln("/* %s", _custom.name);
                output.writefln("%s", _custom.doc.toPretty);
                output.writeln("*/");
            }
        }
        else {
            uint linewidth;
            output.writefln(`/* Custom "%s"`, _custom.name);
            foreach (d; _custom.bytes) {
                if ((d > SPACE) && (d < DEL)) {
                    output.writef(`%c`, char(d));
                    linewidth += 1;
                }
                else {
                    output.writef(`\x%02X`, d);
                    linewidth += 3;
                }
                if (linewidth >= max_linewidth) {
                    output.writeln;
                    linewidth = 0;
                }
            }
            output.writeln(`*/`);
        }
    }

    alias Type = Sections[Section.TYPE];
    void type_sec(ref const(Type) _type) {
        version (none)
            foreach (i, t; _type[].enumerate) {
            output.writef("%s(type (;%d;) (%s", indent, i, typesName(t.type));
            if (t.params.length) {
                output.write(" (param");
                foreach (p; t.params) {
                    output.writef(" %s", typesName(p));
                }
                output.write(")");
            }
            if (t.results.length) {
                output.write(" (result");
                foreach (r; t.results) {
                    output.writef(" %s", typesName(r));
                }
                output.write(")");
            }
            output.writeln("))");
        }
    }

    alias Import = Sections[Section.IMPORT];
    void import_sec(ref const(Import) _import) {
        //        auto _import=*mod[Section.IMPORT];//.import_sec;
        static string importdesc(ref const ImportType imp, const size_t index) {
            const desc = imp.importdesc.desc;
            with (IndexType) {
                final switch (desc) {
                case FUNC:
                    const _funcdesc = imp.importdesc.get!FUNC;
                    return format("(%s (;%d;) (func %d))", indexName(desc),
                            index, _funcdesc.funcidx);
                case TABLE:
                    const _tabledesc = imp.importdesc.get!TABLE;
                    return format("(%s (;%d;) %s %s)", indexName(desc), index,
                            limitToString(_tabledesc.limit), typesName(_tabledesc.type));
                case MEMORY:
                    const _memorydesc = imp.importdesc.get!MEMORY;
                    return format("(%s(;%d;)  %s %s)", indexName(desc), index,
                            limitToString(_memorydesc.limit));
                case GLOBAL:
                    const _globaldesc = imp.importdesc.get!GLOBAL;
                    return format("(%s (;%d;) %s)", indexName(desc), index,
                            globalToString(_globaldesc));
                }
            }
        }

        foreach (i, imp; _import[].enumerate) {
            //            output.writefln("imp=%s", imp);
            output.writefln(`%s(import "%s" "%s" %s)`, indent, imp.mod,
                    imp.name, importdesc(imp, i));
        }
    }

    alias Function = Sections[Section.FUNCTION];
    protected Function _function;
    @trusted void function_sec(ref const(Function) _function) {
        // Empty
        // The function headers are printed in the code section
        this._function = cast(Function) _function;
    }

    alias Table = Sections[Section.TABLE];
    void table_sec(ref const(Table) _table) {
        foreach (i, t; _table[].enumerate) {
            output.writefln("%s(table (;%d;) %s %s)", indent, i,
                    limitToString(t.limit), typesName(t.type));
        }
    }

    alias Memory = Sections[Section.MEMORY];
    void memory_sec(ref const(Memory) _memory) {
        foreach (i, m; _memory[].enumerate) {
            output.writefln("%s(memory (;%d;) %s)", indent, i, limitToString(m.limit));
        }
    }

    alias Global = Sections[Section.GLOBAL];
    void global_sec(ref const(Global) _global) {
        Context ctx;
        const(FuncType) func_void;
        foreach (i, g; _global[].enumerate) {
            output.writefln("%s(global (;%d;) %s (", indent, i, globalToString(g.global));
            auto expr = g[];
            block(expr, func_void, ctx, indent ~ spacer);
            output.writefln("%s))", indent);
        }
    }

    alias Export = Sections[Section.EXPORT];
    private Export _export;
    void export_sec(ref const(Export) _export) {
        this._export = _export.dup;
    }

    ExportType getExport(const int idx) const { //pure nothrow {
        __write("getExport _export %s", _export is null);
        const found = _export[].find!(exp => exp.idx == idx);
        if (found.empty) {
            return ExportType.init;
        }
        return found.front;
    }

    alias Start = Sections[Section.START];
    void start_sec(ref const(Start) _start) {
        output.writefln("%s(start %d),", indent, _start.idx);
    }

    alias Element = Sections[Section.ELEMENT];
    void element_sec(ref const(Element) _element) {
        Context ctx;
        const(FuncType) func_void;
        foreach (i, e; _element[].enumerate) {
            output.writefln("%s(elem (;%d;) (", indent, i);
            auto expr = e[];
            const local_indent = indent ~ spacer;
            block(expr, func_void, ctx, local_indent ~ spacer);
            output.writef("%s) func", local_indent);
            foreach (f; e.funcs) {
                output.writef(" %d", f);
            }
            output.writeln(")");
        }
    }

    static string dType(const Types type) {
        with (Types) {
            final switch (type) {

            case EMPTY:
                return "void";
            case I32:
                return "int";
            case I64:
                return "long";
            case F32:
                return "float";
            case F64:
                return "double";
            case FUNC:
                return "_function_";
            case FUNCREF:
                return "void*";

            }
        }
        assert(0);
    }

    static string dType(const(Types[]) types) {
        if (types.empty) {
            return dType(Types.EMPTY);
        }
        if (types.length == 1) {
            return dType(types[0]);
        }
        return format("Tuple!(%-(%s, %))", types);
    }

    static string return_type(const(Types[]) types) {
        return dType(types);
        //return (types.length == 1) ? dType(types[0]) : "void";
    }

    string function_name(const int index) {
        import std.string;

        __write("function_name %d", index);
        const exp = getExport(index);
        if (exp == ExportType.init) {
            return format("func_%d", index);
        }
        return exp.name.replace(".", "_").replace("-", "_");
    }

    static string param_name(const size_t index) {
        return format("param_%d", index);
    }

    static string function_params(const(Types[]) types) {
        return format("%-(%s, %)", types.enumerate.map!(type => format("%s %s", dType(type.value),
                param_name(type.index))));
    }

    private void output_function(const(TypeIndex) func, const(CodeType) code_type) {
        Context ctx;
        auto expr = code_type[];
        const func_type = wasmstream.get!(Section.TYPE)[func.idx];
        //const x = return_type(func_type.results);
        output.writefln("%s%s %s (%s) {",
                indent,
                return_type(func_type.results),
                function_name(func.idx),
                function_params(func_type.params));
        ctx.locals = iota(func_type.params.length).map!(idx => param_name(idx)).array;
        const local_indent = indent ~ spacer;
        if (!code_type.locals.empty) {
            output.writef("%s(local", local_indent);
            foreach (l; code_type.locals) {
                foreach (i; 0 .. l.count) {
                    output.writef(" %s", typesName(l.type));
                }
            }
            output.writeln(")");
        }

        block(expr, func_type, ctx, local_indent);
        output.writefln("%s}\n", indent);
    }

    alias Code = Sections[Section.CODE];
    @trusted void code_sec(ref const(Code) _code) {
        foreach (f, c; lockstep(_function[], _code[], StoppingPolicy.requireSameLength)) {
            output_function(f, c);
        }
    }

    alias Data = Sections[Section.DATA];
    void data_sec(ref const(Data) _data) {
        Context ctx;
        const(FuncType) func_void;
        foreach (d; _data[]) {
            output.writefln("%s(data (", indent);
            auto expr = d[];
            const local_indent = indent ~ spacer;
            block(expr, func_void, ctx, local_indent ~ spacer);
            output.writefln(`%s) "%s")`, local_indent, d.base);
        }
    }

    struct Context {
        string[] locals;
        string[] stack;
        string peek() const pure nothrow @nogc {
            if (stack.length == 0) {
                return "Error stack is empty";
            }
            return stack[$ - 1];
        }

        string pop() pure nothrow {
            if (stack.length == 0) {
                return "Error pop from an empty stack";
            }
            scope (exit) {
                stack.length--;
            }
            return peek;
        }

        string[] pops(const size_t amount) pure nothrow {
            try {
                scope (success) {
                    stack.length -= amount;
                }
                return stack[$ - amount .. $];
            }
            catch (Exception e) {
                return ["Error Stack underflow", e.msg];
            }
            assert(0);
        }

        void push(string value) pure nothrow {
            stack ~= value;
        }

        bool empty() const pure nothrow @nogc {
            return stack.empty;
        }

        void perform(const IR ir, const(Types[]) args) {
            switch (args.length) {
            case 1:
                if (ir in instr_fmt) {
                    push(format(instr_fmt[ir], pop));
                    return;
                }
                push(format("Undefinded %s pop %s", ir, pop));
                break;
            case 2:
                if (ir in instr_fmt) {
                    push(format(instr_fmt[ir], pop, pop));
                    return;
                }
                push(format("Undefinded %s pops %s %s", ir, pop, pop));
                break;
            case 3:
                if (ir in instr_fmt) {
                    push(format(instr_fmt[ir], pop, pop, pop));
                    return;
                }
                push(format("Undefinded %s pops %s %s %s", ir, pop, pop, pop));
                break;
            default:
                check(0, format("Format arguments (%-(%s %)) not supported for %s", args, instrTable[ir].name));
            }

        }

        void perform(const IR_EXTEND ir, const(Types[]) args) {
            switch (args.length) {
            case 1:
                if (ir in instr_extend_fmt) {
                    push(format(instr_extend_fmt[ir], pop));
                    return;
                }
                push(format("Undefinded %s pop %s", ir, pop));
                break;
            case 2:
                if (ir in instr_extend_fmt) {
                    push(format(instr_extend_fmt[ir], pop, pop));
                    return;
                }
                push(format("Undefinded %s pops %s %s", ir, pop, pop));
                break;
            default:
                check(0, format("Format arguments (%-(%s %)) not supported for %s", args, interExtendedTable[ir].name));
            }

        }

        void push(const IR ir, const uint local_idx) pure nothrow {
            push(locals[local_idx]);
        }
    }

    static string sign(T)(T x) if (isFloatingPoint!T) {
        import std.math : signbit;

        return signbit(x) ? "-" : "";
    }

    private const(ExprRange.IRElement) block(
            ref ExprRange expr,
            ref const(FuncType) func_type,
            ref Context ctx,
            const(string) indent,
            const bool no_return = false) {
        string block_comment;
        uint block_count;
        uint count;
        uint calls;
        static string block_result_type()(const Types t) {
            with (Types) {
                switch (t) {
                case I32, I64, F32, F64, FUNCREF:
                    return format(" (result %s)", typesName(t));
                case EMPTY:
                    return null;
                default:
                    check(0, format("Block Illegal result type %s for a block", t));
                }
            }
            assert(0);
        }

        string result_name() {
            return format("result_%d", calls);
        }

        const(ExprRange.IRElement) innerBlock(
                ref ExprRange expr,
                const(string) indent,
                const uint level) {
            while (!expr.empty) {
                const elm = expr.front;
                //const instr = instrTable[elm.code];
                expr.popFront;

                with (IRType) {
                    final switch (elm.instr.irtype) {
                    case CODE:
                    case CODE_TYPE:
                        output.writefln("%s// %s", indent, elm.instr.name);
                        ctx.perform(elm.code, elm.instr.pops);
                        break;
                    case CODE_EXTEND:
                        output.writefln("%s// %s", indent, elm.instr.name);
                        ctx.perform(cast(IR_EXTEND) elm.instr.opcode, elm.instr.pops);
                        break;
                    case RETURN:
                        output.writefln("%s// %s", indent, elm.instr.name);

                        ctx.perform(elm.code, func_type.results);
                        break;
                    case PREFIX:
                        output.writefln("%s%s", indent, elm.instr.name);
                        break;
                    case BLOCK:
                        block_comment = format(";; block %d", block_count);
                        block_count++;
                        output.writefln("%s%s%s %s", indent, elm.instr.name,
                                block_result_type(elm.types[0]), block_comment);
                        const end_elm = innerBlock(expr, indent ~ spacer, level + 1);
                        const end_instr = instrTable[end_elm.code];
                        output.writefln("%s%s", indent, end_instr.name);
                        //return end_elm;
                        if (end_elm.code is IR.BLOCK) {

                        }
                        // const end_elm=block_elm(elm);
                        else if (end_elm.code is IR.ELSE) {
                            const endif_elm = innerBlock(expr, indent ~ spacer, level + 1);
                            const endif_instr = instrTable[endif_elm.code];
                            output.writefln("%s%s %s count=%d", indent,
                                    endif_instr.name, block_comment, count);
                        }
                        break;
                    case BRANCH:
                        output.writefln("%s%s %s", indent, elm.instr.name, elm.warg.get!uint);
                        /*
                        break;
                    case BRANCH_IF:
                        output.writefln("%s%s %s", indent, elm.instr.name, elm.warg.get!uint);
*/
                        break;
                    case BRANCH_TABLE:
                        static string branch_table(const(WasmArg[]) args) {
                            string result;
                            foreach (a; args) {
                                result ~= format(" %d", a.get!uint);
                            }
                            return result;
                        }

                        output.writefln("%s%s %s", indent, elm.instr.name, branch_table(elm.wargs));
                        break;
                    case CALL:
                        scope (exit) {
                            calls++;
                        }
                        output.writefln("%s// %s %s", indent, elm.instr.name, elm.warg.get!uint);
                        const func_idx = elm.warg.get!uint;
                        const function_header = wasmstream.get!(Section.TYPE)[func_idx];
                        const function_call = format("%s(%-(%s,%))", function_name(func_idx), ctx.pops(function_header
                                .params.length));
                        string set_result;
                        if (function_header.results.length) {
                            set_result = format("const %s=", result_name);
                            ctx.push(result_name);
                        }
                        output.writefln("%s%s%s;", indent, set_result, function_call);
                        break;
                    case CALL_INDIRECT:
                        output.writefln("%s%s (type %d)", indent, elm.instr.name, elm.warg.get!uint);
                        break;
                    case LOCAL:
                        output.writefln("%s// %s %d", indent, elm.instr.name, elm.warg.get!uint);
                        ctx.push(elm.code, elm.warg.get!uint);
                        break;
                    case GLOBAL:
                        output.writefln("%s%s %d", indent, elm.instr.name, elm.warg.get!uint);
                        break;
                    case MEMORY:
                        output.writefln("%s%s%s", indent, elm.instr.name, offsetAlignToString(elm.wargs));
                        break;
                    case MEMOP:
                        output.writefln("%s%s", indent, elm.instr.name);
                        break;
                    case CONST:
                        static string toText(const WasmArg a) {
                            import std.math : isNaN, isInfinity;

                            with (Types) {
                                switch (a.type) {
                                case I32:
                                    return format("(%d)", a.get!int);
                                case I64:
                                    return format("(0x%xL)", a.get!long);
                                case F32:
                                    const x = a.get!float;
                                    if (x.isNaN) {
                                        return format("math.snan!float(0x%x)", a.as!uint);
                                    }
                                    if (x.isInfinity) {
                                        return format("(%sfloat.infinity)", sign(x));
                                    }
                                    return format("float(%aF /* %s */)", x, x);
                                case F64:
                                    const x = a.get!double;
                                    if (x.isNaN) {
                                        return format("math.snan!double(0x%x)", a.as!long);
                                    }
                                    if (x.isInfinity) {
                                        return format("(%sdouble.infinity)", sign(x));
                                    }
                                    return format("double(%a /* %s */)", x, x);
                                default:
                                    assert(0);
                                }
                            }
                            assert(0);
                        }

                        const value = toText(elm.warg);
                        output.writefln("%s// %s %s", indent, elm.instr.name, value);
                        ctx.push(value);
                        break;
                    case END:
                        return elm;
                    case ILLEGAL:
                        output.writefln("Error: Illegal instruction %02X", elm.code);
                        return elm;
                    case SYMBOL:
                        assert(0, "Symbol opcode and it does not have an equivalent opcode");
                    }
                }
            }
            return ExprRange.IRElement(IR.END, level);
        }

        scope (exit) {
            if (!no_return && (ctx.stack.length > 0)) {
                output.writefln("%sreturn %s;", indent, ctx.pop);
            }
            check(no_return || (ctx.stack.length == 0), format("Stack size is %d but the stack should be empty on return", ctx
                    .stack
                    .length));
        }
        return innerBlock(expr, indent, 0);
    }

    Output serialize() {
        output.writefln("module %s;", module_name);
        output.writeln;
        imports.each!(imp => output.writefln("import %s;", imp));
        attributes.each!(attr => output.writefln("%s:", attr));
        //indent = spacer;
        scope (exit) {
            output.writeln("// end");
        }
        wasmstream(this);
        return output;
    }

}

immutable string[IR] instr_fmt;
immutable string[IR_EXTEND] instr_extend_fmt;

shared static this() {
    instr_fmt = [
        IR.LOCAL_GET: q{%1$s},
        IR.LOCAL_SET: q{%2$s=%1$s;},
        // State 
        IR.RETURN: q{%1$s},
        // Const literals
        IR.I32_CONST: q{/* const i32 */},
        IR.I64_CONST: q{/* const i64 */},
        IR.F32_CONST: q{/* const f32 */},
        IR.F64_CONST: q{/* const f64 */},

        // 32 bits integer operations
        IR.I32_CLZ: q{wasm.clz(%s)},
        IR.I32_CTZ: q{wasm.ctz(%s)},
        IR.I32_POPCNT: q{wasm.popcnt(%s)},
        IR.I32_ADD: q{(%2$s + %1$s)},
        IR.I32_SUB: q{(%2$s - %1$s)},
        IR.I32_MUL: q{(%2$s * %1$s)},
        IR.I32_DIV_S: q{wasm.div(%2$s, %1$s)},
        IR.I32_DIV_U: q{wasm.div(uint(%2$s), uint(%1$s))},
        IR.I32_REM_S: q{wasm.rem(%2$s, %1$s)},
        IR.I32_REM_U: q{wasm.rem(uint(%2$s), uint(%1$s))},
        IR.I32_AND: q{(%2$s & %1$s)},
        IR.I32_OR: q{(%2$s | %1$s)},
        IR.I32_XOR: q{(%2$s ^ %1$s)},
        IR.I32_SHL: q{(%2$s << %1$s)},
        IR.I32_SHR_S: q{(%2$s >> %1$s)},
        IR.I32_SHR_U: q{(%2$s >>> %1$s)},
        IR.I32_ROTL: q{wasm.rotl(uint(%2$s), uint(%1$s))},
        IR.I32_ROTR: q{wasm.rotr(uint(%2$s), uint(%1$s))},
        IR.I32_EQZ: q{(%1$s == 0)},
        IR.I32_EQ: q{(%2$s == %1$s)},
        IR.I32_NE: q{(%2$s != %1$s)},
        IR.I32_LT_S: q{(%2$s < %1$s)},
        IR.I32_LT_U: q{(uint(%2$s) < uint(%1$s))},
        IR.I32_LE_S: q{(%2$s <= %1$s)},
        IR.I32_LE_U: q{(uint(%2$s) <= uint(%1$s))},
        IR.I32_GT_S: q{(%2$s > %1$s)},
        IR.I32_GT_U: q{(uint(%2$s) > uint(%1$s))},
        IR.I32_GE_S: q{(%2$s >= %1$s)},
        IR.I32_GE_U: q{(uint(%2$s) >= uint(%1$s))},
        /// 64 bits integer operations
        IR.I64_CLZ: q{wasm.clz(%s)},
        IR.I64_CTZ: q{wasm.ctz(%s)},
        IR.I64_POPCNT: q{wasm.popcnt(%s)},
        IR.I64_ADD: q{(%2$s + %1$s)},
        IR.I64_SUB: q{(%2$s - %1$s)},
        IR.I64_MUL: q{(%2$s * %1$s)},
        IR.I64_DIV_S: q{wasm.div(long(%2$s), long(%1$s))},
        IR.I64_DIV_U: q{wasm.div(ulong(%2$s), ulong(%1$s))},
        IR.I64_REM_S: q{wasm.rem(long(%2$s), long(%1$s))},
        IR.I64_REM_U: q{wasm.rem(ulong(%2$s), ulong(%1$s))},
        IR.I64_AND: q{(%2$s & %1$s)},
        IR.I64_OR: q{(%2$s | %1$s)},
        IR.I64_XOR: q{(%2$s ^ %1$s)},
        IR.I64_SHL: q{(%2$s << %1$s)},
        IR.I64_SHR_S: q{(%2$s >> %1$s)},
        IR.I64_SHR_U: q{(%2$s >>> %1$s)},
        IR.I64_ROTL: q{wasm.rotl(ulong(%2$s), ulong(%1$s))},
        IR.I64_ROTR: q{wasm.rotr(ulong(%2$s), ulong(%1$s))},
        IR.I64_EQZ: q{(%1$s == 0)},
        IR.I64_EQ: q{(%2$s == %1$s)},
        IR.I64_NE: q{(%2$s != %1$s)},
        IR.I64_LT_S: q{(%2$s < %1$s)},
        IR.I64_LT_U: q{(ulong(%2$s) < ulong(%1$s))},
        IR.I64_LE_S: q{(%2$s <= %1$s)},
        IR.I64_LE_U: q{(ulong(%2$s) <= ulong(%1$s))},
        IR.I64_GT_S: q{(%2$s > %1$s)},
        IR.I64_GT_U: q{(ulong(%2$s) > ulong(%1$s))},
        IR.I64_GE_S: q{(%2$s >= %1$s)},
        IR.I64_GE_U: q{(ulong(%2$s) >= ulong(%1$s))},
        /// F32 32bits floatingpoint
        IR.F32_EQ: q{(%2$s is %2$s},
        IR.F32_NE: q{(%2$s != %2$s},
        IR.F32_LT: q{(%2$s < %2$s},
        IR.F32_GT: q{(%2$s > %2$s},
        IR.F32_LE: q{(%2$s <= %2$s},
        IR.F32_GE: q{(%2$s >= %2$s},
        IR.F32_ABS: q{math.fabsf(%1$s)},
        IR.F32_NEG: q{(-%1$s)},
        IR.F32_CEIL: q{math.ceil(%1$s)},
        IR.F32_FLOOR: q{math.floor(%1$s)},
        IR.F32_TRUNC: q{math.trunc(%1$s)},
        IR.F32_NEAREST: q{math.nearest(%1$s)},
        IR.F32_SQRT: q{math.sqrt(%1$s)},
        IR.F32_ADD: q{math.add(%2$s,%1$s)},
        IR.F32_SUB: q{math.sub(%2$s, %1$s)},
        IR.F32_MUL: q{math.mul(%2$s, %1$s)},
        IR.F32_DIV: q{math.div(%2$s, %1$s)},
        IR.F32_MIN: q{math.min(%2$s, %1$s)},
        IR.F32_MAX: q{math.max(%2$s, %1$s)},
        IR.F32_COPYSIGN: q{math.copysignf(%2$s, %1$s)},
        IR.F32_CONVERT_I32_S: q{cast(int)(%1$s)},
        IR.F32_CONVERT_I32_U: q{cast(uint)(%1$s)},
        IR.F32_CONVERT_I64_S: q{cast(long)(%1$s)},
        IR.F32_CONVERT_I64_U: q{cast(ulong)(%1$s)},
        IR.F32_DEMOTE_F64: q{math.demote(%1$s)},

        /// F64 32bits floatingpoint
        IR.F64_EQ: q{(%2$s == %2$s},
        IR.F64_NE: q{(%2$s != %2$s},
        IR.F64_LT: q{(%2$s < %2$s},
        IR.F64_GT: q{(%2$s > %2$s},
        IR.F64_LE: q{(%2$s <= %2$s},
        IR.F64_GE: q{(%2$s >= %2$s},
        IR.F64_ABS: q{math.fabs(%1$s)},
        IR.F64_NEG: q{(-%1$s)},
        IR.F64_CEIL: q{math.ceil(%1$s)},
        IR.F64_FLOOR: q{math.floor(%1$s)},
        IR.F64_TRUNC: q{math.trunc(%1$s)},
        IR.F64_NEAREST: q{math.nearest(%1$s)},
        IR.F64_SQRT: q{math.sqrt(%1$s)},
        IR.F64_ADD: q{math.add(%2$s, %1$s)},
        IR.F64_SUB: q{math.sub(%2$s, %1$s)},
        IR.F64_MUL: q{math.mul(%2$s, %1$s)},
        IR.F64_DIV: q{math.div(%2$s,  %1$s)},
        IR.F64_MIN: q{math.min(%2$s, %1$s)},
        IR.F64_MAX: q{math.max(%2$s, %1$s)},
        IR.F64_COPYSIGN: q{math.copysign(%2$s, %1$s)},
        IR.F64_CONVERT_I32_S: q{cast(int)(%1$s)},
        IR.F64_CONVERT_I32_U: q{cast(uint)(%1$s)},
        IR.F64_CONVERT_I64_S: q{cast(long)(%1$s)},
        IR.F64_CONVERT_I64_U: q{cast(ulong)(%1$s)},
        // Conversions
        IR.I64_EXTEND_I32_S: q{cast(long)(%1$s)},
        IR.I64_EXTEND_I32_U: q{cast(long)(cast(uint)%1$s)},
        IR.I32_EXTEND8_S: q{cast(int)(cast(byte)%1$s)},
        IR.I32_EXTEND16_S: q{cast(int)(cast(short)%1$s)},
        IR.I64_EXTEND8_S: q{cast(long)(cast(byte)%1$s)},
        IR.I64_EXTEND16_S: q{cast(long)(cast(short)%1$s)},
        IR.I64_EXTEND32_S: q{cast(long)(cast(int)%1$s)},

        IR.I32_WRAP_I64: q{cast(int)(%1$s)},
        IR.I32_TRUNC_F32_S: q{math.trunc!(int,float)(%1$s)},
        IR.I32_TRUNC_F32_U: q{math.trunc!(uint,float)(%1$s)},
        IR.I32_TRUNC_F64_S: q{math.trunc!(int,double)(%1$s)},
        IR.I32_TRUNC_F64_U: q{math.trunc!(uint,double)(%1$s)},
        IR.I64_TRUNC_F32_S: q{math.trunc!(long,float)(%1$s)},
        IR.I64_TRUNC_F32_U: q{math.trunc!(ulong,float)(%1$s)},
        IR.I64_TRUNC_F64_S: q{math.trunc!(long,double)(%1$s)},
        IR.I64_TRUNC_F64_U: q{math.trunc!(ulong,double)(%1$s)},

        IR.F32_CONVERT_I32_S: q{cast(float)(%1$s)},
        IR.F32_CONVERT_I32_U: q{cast(float)(cast(uint)%1$s)},
        IR.F32_CONVERT_I64_S: q{cast(float)(%1$s)},
        IR.F32_CONVERT_I64_U: q{cast(float)(cast(ulong)%1$s)},
        IR.F64_CONVERT_I32_S: q{cast(double)(%1$s)},
        IR.F64_CONVERT_I32_U: q{cast(double)(cast(uint)%1$s)},
        IR.F64_CONVERT_I64_S: q{cast(double)(%1$s)},
        IR.F64_CONVERT_I64_U: q{cast(double)(cast(ulong)%1$s)},

        IR.F64_PROMOTE_F32: q{math.promote(%1$s)},

        IR.I32_REINTERPRET_F32: q{math.reinterpret32(%1$s)},
        IR.F32_REINTERPRET_I32: q{math.reinterpret32(%1$s)},
        IR.I64_REINTERPRET_F64: q{math.reinterpret64(%1$s)},
        IR.F64_REINTERPRET_I64: q{math.reinterpret64(%1$s)},
        // Compare f32
        IR.F32_EQ: q{(%2$s == %1$s)},
        IR.F32_NE: q{(%2$s != %1$s)},
        IR.F32_LT: q{(%2$s < %1$s)},
        IR.F32_GT: q{(%2$s > %1$s)},
        IR.F32_LE: q{(%2$s <= %1$s)},
        IR.F32_GE: q{(%2$s >= %1$s)},

        // Compare f64
        IR.F64_EQ: q{(%2$s == %1$s)},
        IR.F64_NE: q{(%2$s != %1$s)},
        IR.F64_LT: q{(%2$s < %1$s)},
        IR.F64_GT: q{(%2$s > %1$s)},
        IR.F64_LE: q{(%2$s <= %1$s)},
        IR.F64_GE: q{(%2$s >= %1$s)},
        //  
        IR.SELECT: q{((%1$s)?%3$s:%2$s)},
    ];
    instr_extend_fmt = [
        IR_EXTEND.I32_TRUNC_SAT_F32_S: q{math.trunc_sat!(int,float)(%1$s)},
        IR_EXTEND.I32_TRUNC_SAT_F32_U: q{math.trunc_sat!(uint,float)(%1$s)},
        IR_EXTEND.I32_TRUNC_SAT_F64_S: q{math.trunc_sat!(int,double)(%1$s)},
        IR_EXTEND.I32_TRUNC_SAT_F64_U: q{math.trunc_sat!(uint,double)(%1$s)},
        IR_EXTEND.I64_TRUNC_SAT_F32_S: q{math.trunc_sat!(long,float)(%1$s)},
        IR_EXTEND.I64_TRUNC_SAT_F32_U: q{math.trunc_sat!(ulong,float)(%1$s)},
        IR_EXTEND.I64_TRUNC_SAT_F64_S: q{math.trunc_sat!(long,double)(%1$s)},
        IR_EXTEND.I64_TRUNC_SAT_F64_U: q{math.trunc_sat!(ulong,double)(%1$s)},
    ];
}

version (none) unittest {
    import std.exception : assumeUnique;
    import std.file;
    import std.stdio;

    //      import std.file : fread=read, fwrite=write;

    @trusted static immutable(ubyte[]) fread(R)(R name, size_t upTo = size_t.max) {
        import std.file : _read = read;

        auto data = cast(ubyte[]) _read(name, upTo);
        // writefln("read data=%s", data);
        return assumeUnique(data);
    }

    //    string filename="../tests/wasm/func_1.wasm";
    //    string filename="../tests/wasm/global_1.wasm";
    //    string filename="../tests/wasm/imports_1.wasm";
    //    string filename="../tests/wasm/table_copy_2.wasm";
    //    string filename="../tests/wasm/memory_2.wasm";
    //    string filename="../tests/wasm/start_4.wasm";
    //    string filename="../tests/wasm/address_1.wasm";
    string filename = "../tests/wasm/data_4.wasm";
    immutable code = fread(filename);
    auto wasm = WasmReader(code);
    //    auto dasm=Wdisasm(wasm);
    Wast(wasm, stdout).serialize();
    //    auto output=Wast

}
