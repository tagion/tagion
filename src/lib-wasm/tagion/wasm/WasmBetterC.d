module tagion.wasm.WasmBetterC;

import std.format;
import std.stdio;
import std.traits : EnumMembers, PointerTarget, ConstOf, ForeachType;
import std.typecons : Tuple;
import std.uni : toLower;
import std.conv : to;
import std.range.primitives : isOutputRange;
import std.range;
import std.algorithm;
import std.array;
import std.typecons;
import std.array;

import tagion.wasm.WasmReader;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmException;
import tagion.basic.tagionexceptions;
import tagion.hibon.Document;
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
    this(WasmReader wasmstream, Output output, string spacer = "  ") {
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
            auto expr = ExprRange(_assert.invoke);
            output.writefln("expr %(%02X %)", _assert.invoke);
            block(expr, ctx, indent);

        }

        foreach (_assert; sec_assert.asserts) {
            output.writefln("%s{", indent);
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
        foreach (i, g; _global[].enumerate) {
            output.writefln("%s(global (;%d;) %s (", indent, i, globalToString(g.global));
            auto expr = g[];
            block(expr, ctx, indent ~ spacer);
            output.writefln("%s))", indent);
        }
    }

    alias Export = Sections[Section.EXPORT];
    private Export _export;
    void export_sec(ref const(Export) _export) {
        this._export = _export.dup;
    }

    ExportType getExport(const int idx) const { //pure nothrow {
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
        foreach (i, e; _element[].enumerate) {
            output.writefln("%s(elem (;%d;) (", indent, i);
            auto expr = e[];
            const local_indent = indent ~ spacer;
            block(expr, ctx, local_indent ~ spacer);
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

    static string return_type(const(Types[]) types) {
        return (types.length == 1) ? dType(types[0]) : "void";
    }

    string function_name(const int index) {
        const exp = getExport(index);
        if (exp == ExportType.init) {
            return format("func_%d", index);
        }
        return exp.name;
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
        const function_header = wasmstream.get!(Section.TYPE)[func.idx];
        const x = return_type(function_header.results);
        output.writefln("%s%s %s (%s) {",
                indent,
                return_type(function_header.results),
                function_name(func.idx),
                function_params(function_header.params));
        ctx.locals = iota(function_header.params.length).map!(idx => param_name(idx)).array;
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

        block(expr, ctx, local_indent);
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
        foreach (d; _data[]) {
            output.writefln("%s(data (", indent);
            auto expr = d[];
            const local_indent = indent ~ spacer;
            block(expr, ctx, local_indent ~ spacer);
            output.writefln(`%s) "%s")`, local_indent, d.base);
        }
    }

    struct Context {
        string[] locals;
        string[] stack;
        string peek() const pure nothrow @nogc {
            return stack[$ - 1];
        }

        string pop() pure nothrow {
            scope (exit) {
                stack.length--;
            }
            return peek;
        }

        void push(string value) pure nothrow {
            stack ~= value;
        }

        bool empty() const pure nothrow @nogc {
            return stack.empty;
        }

        void perform(const IR ir, const uint number_of_args) {
            switch (number_of_args) {
            case 1:
                push(format(instr_fmt[ir], pop));
                return;
            case 2:
                push(format(instr_fmt[ir], pop, pop));
                return;
            default:
                check(0, format("Format argument %s not supported for %s", number_of_args, instrTable[ir].name));
            }

        }

        void push(const IR ir, const uint local_idx) pure nothrow {
            push(locals[local_idx]);
        }
    }

    private const(ExprRange.IRElement) block(
            ref ExprRange expr,
            ref Context ctx,
            const(string) indent) {
        string block_comment;
        uint block_count;
        uint count;
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

        const(ExprRange.IRElement) innerBlock(ref ExprRange expr, const(string) indent, const uint level) {
            while (!expr.empty) {
                const elm = expr.front;
                const instr = instrTable[elm.code];
                expr.popFront;

                with (IRType) {
                    final switch (instr.irtype) {
                    case CODE:
                        output.writefln("%s// %s", indent, instr.name);
                        ctx.perform(elm.code, instr.pops);
                        break;
                    case PREFIX:
                        output.writefln("%s%s", indent, instr.name);
                        break;
                    case BLOCK:
                        block_comment = format(";; block %d", block_count);
                        block_count++;
                        output.writefln("%s%s%s %s", indent, instr.name,
                                block_result_type(elm.types[0]), block_comment);
                        const end_elm = innerBlock(expr, indent ~ spacer, level + 1);
                        const end_instr = instrTable[end_elm.code];
                        output.writefln("%s%s", indent, end_instr.name);
                        //return end_elm;

                        // const end_elm=block_elm(elm);
                        if (end_elm.code is IR.ELSE) {
                            const endif_elm = innerBlock(expr, indent ~ spacer, level + 1);
                            const endif_instr = instrTable[endif_elm.code];
                            output.writefln("%s%s %s count=%d", indent,
                                    endif_instr.name, block_comment, count);
                        }
                        break;
                    case BRANCH:
                    case BRANCH_IF:
                        output.writefln("%s%s %s", indent, instr.name, elm.warg.get!uint);
                        break;
                    case BRANCH_TABLE:
                        static string branch_table(const(WasmArg[]) args) {
                            string result;
                            foreach (a; args) {
                                result ~= format(" %d", a.get!uint);
                            }
                            return result;
                        }

                        output.writefln("%s%s %s", indent, instr.name, branch_table(elm.wargs));
                        break;
                    case CALL:
                        output.writefln("%s%s %s", indent, instr.name, elm.warg.get!uint);
                        break;
                    case CALL_INDIRECT:
                        output.writefln("%s%s (type %d)", indent, instr.name, elm.warg.get!uint);
                        break;
                    case LOCAL:
                        output.writefln("%s// %s %d", indent, instr.name, elm.warg.get!uint);
                        ctx.push(elm.code, elm.warg.get!uint);
                        break;
                    case GLOBAL:
                        output.writefln("%s%s %d", indent, instr.name, elm.warg.get!uint);
                        break;
                    case MEMORY:
                        output.writefln("%s%s%s", indent, instr.name, offsetAlignToString(elm.wargs));
                        break;
                    case MEMOP:
                        output.writefln("%s%s", indent, instr.name);
                        break;
                    case CONST:
                        static string toText(const WasmArg a) {
                            with (Types) {
                                switch (a.type) {
                                case I32:
                                    return a.get!int
                                        .to!string;
                                case I64:
                                    return a.get!long
                                        .to!string;
                                case F32:
                                    const x = a.get!float;
                                    return format("%a (;=%s;)", x, x);
                                case F64:
                                    const x = a.get!double;
                                    return format("%a (;=%s;)", x, x);
                                default:
                                    assert(0);
                                }
                            }
                            assert(0);
                        }

                        output.writefln("%s%s %s", indent, instr.name, toText(elm.warg));
                        break;
                    case END:
                        return elm;
                    case SYMBOL:
                        assert(0, "Symbol opcode and it does not have an equivalent opcode");
                    }
                }
            }
            return ExprRange.IRElement(IR.END, level);
        }

        scope (exit) {
            if (ctx.stack.length > 0) {
                output.writefln("%sreturn %s;", indent, ctx.pop);
            }
            check(ctx.stack.length == 0, format("Stack size is %d but the stack should be empty on return", ctx.stack
                    .length));
        }
        return innerBlock(expr, indent, 0);
    }

    Output serialize() {
        output.writefln("module %s;", module_name);
        output.writeln;
        imports.each!(imp => output.writefln("import %s;", imp));
        //indent = spacer;
        scope (exit) {
            output.writeln("// end");
        }
        wasmstream(this);
        return output;
    }

}

immutable string[IR] instr_fmt;

shared static this() {
    instr_fmt = [
        IR.LOCAL_GET: q{%1$s},
        IR.LOCAL_SET: q{%2$s=$1$s;},
        IR.I32_CLZ: q{wasm.clz(%s)},
        IR.I32_CTZ: q{wasm.clz(%s)},
        IR.I32_POPCNT: q{wasm.popcnt(%s)},
        IR.I32_ADD: q{(%1$s + %2$s)},
        IR.I32_SUB: q{(%1$s - %2$s)},
        IR.I32_MUL: q{(%1$s * %2$s)},
        IR.I32_DIV_S: q{(%1$s / %2$s)},
        IR.I32_DIV_U: q{uint(%1$s) / uint(%2$s)},
        IR.I32_REM_S: q{(%1$s %% %2$s)},
        IR.I32_REM_U: q{(uint(%1$s) %% uint(%2$s))},
        IR.I32_AND: q{(%1$s & %2$s)},
        IR.I32_OR: q{(%1$s | %2$s)},
        IR.I32_XOR: q{(%1$s ^ %2$s)},
        IR.I32_SHL: q{(%1$s >> %2$s)},
        IR.I32_SHR_S: q{(%1$s >> %2$s)},
        IR.I32_SHR_U: q{(%1$s >>> %2$s)},
        IR.I32_ROTL: q{wasm.rotl(%1$s, %2$s)},
        IR.I32_ROTR: q{wasm.rotr(%1$s, %2$s)},
        IR.I32_EQZ: q{(%1$s == 0)},
        IR.I32_EQ: q{(%1$s == %2$s)},
        IR.I32_NE: q{(%1$s != %2$s)},
        IR.I32_LT_S: q{(%1$s < %2$s)},
        IR.I32_LT_U: q{(uint(%1$s) < uint(%2$s))},
        IR.I32_LE_S: q{(%1$s <= %2$s)},
        IR.I32_LE_U: q{(uint(%1$s) <= uint(%2$s))},
        IR.I32_GT_S: q{(%1$s > %2$s)},
        IR.I32_GT_U: q{(uint(%1$s) > uint(%2$s))},
        IR.I32_GE_S: q{(%1$s >= %2$s)},
        IR.I32_GE_U: q{(uint(%1$s) >= uint(%2$s))},

    ];
}

version (none) unittest {
    import std.stdio;
    import std.file;
    import std.exception : assumeUnique;

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
