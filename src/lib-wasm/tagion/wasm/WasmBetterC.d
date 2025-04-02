module tagion.wasm.WasmBetterC;

import tagion.basic.Debug;

import std.exception;
import std.algorithm;
import std.array;
import std.conv : to;
import std.format;
import std.range;
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

@safe:
class WasmBetterCException : WasmException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!WasmBetterCException;

WasmBetterC!(Output) wasmBetterC(Output)(WasmReader wasmreader, Output output) {
    return new WasmBetterC!(Output)(wasmreader, output);
}

class WasmBetterC(Output) : WasmReader.InterfaceModule {
    alias Sections = WasmReader.Sections;
    alias ImportType = WasmReader.WasmRange.WasmSection.ImportType;
    alias ExportType = WasmReader.WasmRange.WasmSection.ExportType;
    alias FuncType = WasmReader.WasmRange.WasmSection.FuncType;
    alias FuncIndex = WasmReader.WasmRange.WasmSection.FuncIndex;
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
        void innerAssert(const Assert _assert, const string indent) @safe {
            auto ctx = new Context;
            const(FuncType) func_void;
            auto code_type = CodeType(_assert.invoke);
            auto invoke_expr = code_type[];
            output.writefln("%s// expr   %(%02X %)", indent, _assert.invoke);
            output.writefln("%s// result %(%02X %)", indent, _assert.result);
            with (Assert.Method) final switch (_assert.method) {
            case Trap:
                void assert_block(const string _indent) {
                    block(invoke_expr, func_void, ctx, _indent ~ spacer, true);
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
                auto ctx_results = new Context;
                block(result_expr, func_void, ctx_results, indent, true);
                output.writefln("%s// %s : %s", indent, ctx.stack, ctx_results.stack);
                if (ctx.stack.length) {
                    output.writefln("%s// %s", indent, ctx_results);
                    if (ctx_results.stack.length == 1) {
                        output.writef("%sassert(%s is %s", indent, ctx.pop, ctx_results.pop);
                    }
                    else {
                        string[] checks;
                        foreach (i, a; ctx_results.stack) {
                            checks ~= format("(%s[%d] is %s)",
                                    ctx.stack[0], i, ctx_results.stack[i]);
                        }
                        output.writef("%sassert(%-(%s &&%)", indent, checks);
                    }
                    if (_assert.message.length) {
                        output.writef(`, "%s"`, _assert.message);
                    }
                    output.writeln(");");
                }
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
        auto ctx = new Context;
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
        auto ctx = new Context;
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

            case VOID:
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
            return dType(Types.VOID);
        }
        if (types.length == 1) {
            return dType(types[0]);
        }
        return format("Tuple!(%-(%s, %))", types.map!(t => dType(t)));
    }

    static string return_type(const(Types[]) types) {
        return dType(types);
    }

    string dType(ref const ExprRange.IRElement elm) {
        if (elm.argtype == ExprRange.IRElement.IRArgType.TYPES) {
            return dType(elm.types);
        }
        return dType(wasmstream.get!(Section.TYPE)[elm.idx].results);
    }

    const(Types[]) types(ref const ExprRange.IRElement elm) const pure {
        if (elm.argtype == ExprRange.IRElement.IRArgType.TYPES) {
            return elm.types;
        }
        return wasmstream.get!(Section.TYPE)[elm.idx].results;
    }

    string function_name(const int index) {
        import std.string;

        const exp = getExport(index);
        if (exp == ExportType.init) {
            return format("func_%d", index);
        }
        import tagion.wasm.dkeywords : isDKeyword;

        if (isDKeyword(exp.name)) {
            return "Dword_" ~ exp.name;
        }
        return exp.name.replace(".", "_").replace("-", "_");
    }

    static string param_name(const size_t index) nothrow {
        return assumeWontThrow(format("param_%d", index));
    }

    static string function_params(const(Types[]) types) {
        return format("%-(%s, %)", types.enumerate.map!(type => format("%s %s", dType(type.value),
                param_name(type.index))));
    }

    private void output_function(const int func_idx, const(FuncIndex) type, const(CodeType) code_type) {
        auto expr = code_type[];
        const func_type = wasmstream.get!(Section.TYPE)[type.idx];
        output.writefln("%s%s %s (%s) {",
                indent,
                return_type(func_type.results),
                function_name(func_idx),
                function_params(func_type.params));
        auto ctx = new Context(func_type, code_type);
        const local_indent = indent ~ spacer;
        if (!code_type.locals.empty) {
            output.writefln("%s// context locals %s", local_indent, ctx.locals);
            output.writefln("%s// locals %s", local_indent, code_type.locals);
            const(string)[] local_names = ctx.scope_local_names;
            foreach (l; code_type.locals) {
                string value;
                switch (l.type) {
                case Types.F32:
                    value = format("=%a", float(0));
                    break;
                case Types.F64:
                    value = format("=%a", double(0));
                    break;
                default:
                    // Standard default
                }
                output.writefln("%s%s %-(%s, %);", local_indent, dType(l.type), local_names.take(
                        l.count)
                        .map!(name => name ~ value));
                local_names = local_names[l.count .. $];
            }
        }

        block(expr, func_type, ctx, local_indent);
        output.writefln("%s}\n", indent);
    }

    alias Code = Sections[Section.CODE];
    @trusted void code_sec(ref const(Code) _code) {
        auto func_indices = iota(cast(int) _function[].walkLength);
        foreach (func_idx, f, c; lockstep(func_indices, _function[], _code[], StoppingPolicy
                .requireSameLength)) {
            output_function(func_idx, f, c);
        }
    }

    alias Data = Sections[Section.DATA];
    void data_sec(ref const(Data) _data) {
        auto ctx = new Context;
        const(FuncType) func_void;
        foreach (d; _data[]) {
            output.writefln("%s(data (", indent);
            auto expr = d[];
            const local_indent = indent ~ spacer;
            block(expr, func_void, ctx, local_indent ~ spacer);
            output.writefln(`%s) "%s")`, local_indent, d.base);
        }
    }

    static uint block_count;
    @safe final class Context {
        const(string[]) local_names; /// Locals include the function params
        const(string[]) scope_local_names; /// Locals declared inside the function
        string[] locals; /// Current value-expressions of locals
        string[] stack; /// Value-expression on the stack

        this() {
            local_names = null;
            scope_local_names = null;
        }

        this(const(FuncType) func_type, const(CodeType) code_type) pure nothrow
        in (locals.length == 0, "Locals has already been declared")
        do {
            auto _local_names = iota(func_type.params.length).map!(idx => param_name(idx)).array;
            if (!code_type.locals.empty) {
                _local_names ~= iota(locals.length, locals.length + code_type.locals
                        .map!(l => l.count).sum)
                    .map!(local_idx => assumeWontThrow(format("local_%d", local_idx)))
                    .array;
                //locals ~= local_names;
            }
            local_names = _local_names;
            locals = _local_names.dup;
            scope_local_names = _local_names[func_type.params.length .. $];

        }

        protected Block*[] _blocks;
        override string toString() const pure nothrow {

            return assumeWontThrow(format("locals=%s stack=%s", locals, stack));
        }

        Block* create(const ref ExprRange.IRElement elm) nothrow {
            auto blk = new Block(this, elm, stack.length, cast(uint) _blocks.length, block_count);
            _blocks ~= blk;
            block_count++;
            return blk;
        }

        void dropBlock() pure nothrow {
            _blocks.length--;
        }

        uint number_of_blocks() const pure nothrow {
            return cast(uint) _blocks.length;
        }

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

        string[] pops() pure nothrow {
            scope (exit) {
                stack = null;
            }
            return stack;
        }

        void push(string value) pure nothrow {
            stack ~= value;
        }

        void push(const(Block*) blk) pure {
            if (!blk.isVoidType) {
                const block_types = types(blk.elm);
                if (block_types.length == 1) {
                    push(blk.block_result);
                    return;
                }
                foreach_reverse (i; 0 .. block_types.length) {
                    const value = assumeWontThrow(format("%s[%d]", blk.block_result, i));
                    push(value);
                }

            }
        }

        bool empty() const pure nothrow @nogc {
            return stack.empty;
        }

        void perform(const IR ir, const(Types[]) args) {
            switch (args.length) {
            case 0:
                return;
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
                check(0, format("Format arguments (%-(%s %)) not supported for %s", args, instrTable[ir]
                        .name));
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
                check(0, format("Format arguments (%-(%s %)) not supported for %s", args, interExtendedTable[ir]
                        .name));
            }

        }

        void get(const uint local_idx) pure nothrow {

            push(local_names[local_idx]);
        }

        void set(const uint local_idx) pure nothrow {
            __write("Stack %-(%s, %) local_idx=%d", stack, local_idx);
            __write("Local %-(%s, %) local_idx=%d", locals, local_idx);
            locals[local_idx] = pop;
        }

        string label(const uint block_index) pure {
            check(block_index < _blocks.length,
                    format("Block stack exceeds to %d but the stack size is only %d",
                    block_index, _blocks.length)
            );
            return _blocks[block_index].label;
        }

        uint index(const uint block_depth) const pure {
            check(block_depth < _blocks.length,
                    format("Block stack overflow (stack size %d but block depth is %d)",
                    _blocks.length, block_depth));
            return cast(uint)(_blocks.length - block_depth - 1);
        }

        string goto_label(const uint block_index) pure {
            _blocks[block_index].define_label;
            return label(block_index);
        }

        string block_type(const(Block*) blk) const pure {
            with (ExprRange.IRElement.IRArgType) {
                assert(blk.elm.argtype is TYPES || blk.elm.argtype is INDEX,
                        "Invalid block type");
                if (blk.elm.argtype is INDEX) {
                    const sec_type = wasmstream.get!(Section.TYPE);
                    const func_type = sec_type[blk.elm.idx];
                    return dType(func_type.results);
                }
            }
            with (Types) {
                const elm_type = blk.elm.types[0];
                switch (elm_type) {
                case I32, I64, F32, F64, FUNCREF:
                    return dType(elm_type);
                case VOID:
                    return null;
                default:
                    check(0, format("Block illegal result type %s for a block", elm_type));

                }
            }
            assert(0);
        }

        inout(Block*) current() inout pure nothrow {
            return _blocks[$ - 1];
        }

        inout(Block*) opIndex(const size_t index) inout pure nothrow {
            return _blocks[index];
        }

        string jump(Block* target_block) const pure nothrow {
            if (target_block is current) {
                if (current.elm.code is IR.LOOP) {
                    return "continue";
                }
                return "break";
            }
            if (current.elm.code is IR.LOOP) {
                //if (target_block.elm.code is IR.LOOP) {
                return assumeWontThrow(format("continue %s", target_block.label));
                //}
                //return assumeWontThrow(format("goto %s", target_block.label));

            }
            return assumeWontThrow(format("break %s", target_block.label));
        }

        string declare(Block* blk) pure {
            if (blk.isVoidType) {
                return null;
            }
            scope (exit) {
                blk.define_local;
            }
            return format("%s %s", block_type(blk), blk.block_result);
        }

    }

    enum BlockKind {
        BLOCK, /// block -  block_#: do { .. } while (false);
        LOOP, /// loop - block_#: do { ... } while (false);
        WHILE, /// loop - block_#: while (?) { ... }
        DO_WHILE, /// loop - block_#: do { ... } while (?);
        END, ///  END - if (?) {  .... }
    }

    struct Block {
        const(ExprRange.IRElement) elm;
        const(size_t) sp; /// Stack pointer;
        const(size_t) id;
        const(uint) idx; /// Block idx
        string condition;
        protected {
            Context ctx;
            bool _local_defined;
            bool _label_defined;
            BlockKind _kind;
        }
        @disable this();
        this(Context ctx,
                const ref ExprRange.IRElement elm,
                const size_t sp,
                const uint idx,
                const uint current_id) pure nothrow
        in (only(IRType.BLOCK_CONDITIONAL, IRType.BLOCK, IRType.BLOCK_ELSE)
                .canFind(elm.instr.irtype))

        do {
            this.ctx = ctx;
            this.elm = elm;
            this.sp = sp;
            this.idx = idx;
            id = current_id;
        }

        string begin() const pure nothrow {
            switch (elm.code) {
            case IR.IF:
                assert(condition, "No conidtion of IF");
                return assumeWontThrow(format("if (%s) {", condition));
            case IR.BLOCK:
                return "do {";
            case IR.LOOP:
                //if (begin_kind is _BlockKind.WHILE) {
                if (condition) {
                    return assumeWontThrow(format("while (!%s) {", condition));
                }
                return "do {";
            default:
                assert(0, assumeWontThrow(
                        format("Instruction %s can't be used as a block begin", elm.code)));
            }
        }

        string end() const pure nothrow {
            final switch (_kind) {
            case BlockKind.WHILE:
            case BlockKind.END:
                return "}";
            case BlockKind.DO_WHILE:
                if (condition) {
                    return assumeWontThrow(format("} while(%s);", condition));
                }
                return "} while(true);";
            case BlockKind.BLOCK:
                if (condition) {
                    return "}";
                }
                goto case;
            case BlockKind.LOOP:
                return "} while(false);";
            }
        }

        const(BlockKind) kind() const pure nothrow {
            return _kind;
        }

        void kind(const BlockKind k) nothrow
        in (k > _kind, assumeWontThrow(format("%s <= %s", k, _kind)))
        do {
            _kind = k;
        }

        bool local_defined() const pure nothrow {
            return _local_defined;
        }

        void define_local() pure nothrow {
            _local_defined = true;
        }

        string block_result() const pure nothrow {
            return assumeWontThrow(format("block_result_%d", id));
        }

        string label() pure {
            _label_defined = true;
            return format("block_%d", id);
        }

        void define_label() pure nothrow {
            _label_defined = true;
        }

        bool label_defined() const pure nothrow {
            return _label_defined;
        }

        bool isVoidType() const pure nothrow {
            with (ExprRange.IRElement.IRArgType) {
                return ((elm.argtype is TYPES) && (elm.types[0] is Types.VOID));
            }
        }

    }

    static string sign(T)(T x) if (isFloatingPoint!T) {
        import std.math : signbit;

        return signbit(x) ? "-" : "";
    }

    private void block(
            ref ExprRange expr,
            ref const(FuncType) func_type,
            Context ctx,
            const(string) indent,
            const bool no_return = false) {
        uint calls;
        string result_name() {
            return format("result_%d", calls);
        }

        import std.outbuffer;

        string results(const(Types[]) args) {
            if (args.length == 0) {
                return null;
            }
            if (args.length == 1) {
                return ctx.peek;
            }
            check(args.length <= ctx.stack.length,
                    format("Elements in the stack is %d but the function return arguments is %d",
                    args.length, ctx.stack.length));
            return format("%s(%-(%s, %))", dType(args), args.length.iota.map!(
                    n => ctx.stack[$ - 1 - n]));
        }

        string results_value() {
            if (func_type.results.length == 1) {
                return ctx.pop;
            }
            if (func_type.results.length) {
                return format("%s(%-(%s, %))",
                        dType(func_type.results),
                        ctx.pops.take(func_type.results.length));
            }

            return null;
        }

        void innerBlock(
                OutBuffer bout,
                ref ExprRange expr,
                const(string) indent) {

            void declare_block(Block* blk) {
                const declare = ctx.declare(blk);
                if (declare) {
                    bout.writefln("%s%s;", indent, declare);
                }
                if (blk.label_defined) {
                    bout.writefln("%s%s:", indent, blk.label);
                }
            }

            void set_local(Block* blk) {
                if (!blk.isVoidType) {
                    const block_types = types(blk.elm);
                    if (block_types.length == 1) {
                        bout.writefln("%s%s = %s;", indent, blk.block_result, ctx.pop);
                    }
                    else {
                        foreach (i; 0 .. block_types.length) {
                            const result_local = format("%s[%d]", blk.block_result, i);
                            bout.writefln("%s%s = %s;", indent, result_local, ctx.pop);
                        }
                    }
                    blk.define_local;
                }
            }

            while (!expr.empty) {
                const elm = expr.front;
                expr.popFront;
                with (IRType) {
                    final switch (elm.instr.irtype) {
                    case CODE:
                    case CODE_TYPE:
                        bout.writefln("%s// %s", indent, elm.instr.name);
                        ctx.perform(elm.code, elm.instr.pops);
                        break;
                    case CODE_EXTEND:
                        bout.writefln("%s// %s", indent, elm.instr.name);
                        ctx.perform(cast(IR_EXTEND) elm.instr.opcode, elm.instr.pops);
                        break;
                    case RETURN:

                        bout.writefln("%s%s %s;", indent, elm.instr.name, results_value);
                        break;
                    case OP_STACK:
                        switch (elm.code) {
                        case IR.DROP:
                            const __value = ctx.peek;
                            bout.writefln("%s// drop %s", indent, ctx.pop);
                            __write("%s// drop %s", indent, __value);
                            break;
                        default:
                            assert(0, format("Illegal instruction %s", elm.code));
                        }
                        break;
                    case PREFIX:
                        bout.writefln("%s%s", indent, elm.instr.name);
                        break;
                    case BLOCK_CONDITIONAL:
                    case BLOCK:
                        auto block = ctx.create(elm); //new Block(elm, ctx.stack.length);
                        bout.writefln("%s// block %d", indent, block.id);

                        auto block_bout = new OutBuffer;
                        scope (exit) {
                            block_bout = null;
                        }
                        switch (elm.code) {
                        case IR.IF:
                            ctx.perform(elm.code, elm.instr.pops);
                            block.condition = ctx.pop;
                            block.kind = BlockKind.END;
                            break;
                        case IR.LOOP:
                            block.kind = BlockKind.LOOP;
                            break;
                        default:
                            //block.begin ~= format("%sdo { // %s", indent, block_comment);
                        }
                        scope (success) {
                            ctx.dropBlock;
                        }
                        innerBlock(block_bout, expr, indent ~ spacer);
                        declare_block(ctx.current);
                        bout.writefln("%s%s", indent, block.begin);
                        bout.write(block_bout);
                        bout.writefln("%s%s", indent, block.end);
                        ctx.stack.length = block.sp;
                        ctx.push(block);
                        if (ctx.number_of_blocks > 1) {
                            const outer_block_index = ctx.index(1);
                            const outer_block = ctx[outer_block_index];
                            if (!outer_block.isVoidType && ctx.current.local_defined) {
                                bout.writefln("%s%s = %s;", indent, outer_block.block_result, ctx
                                        .current.block_result);
                            }
                        }
                        bout.writefln("// END stack %-(%s, %)", ctx.stack);
                        break;
                    case BLOCK_ELSE:
                        bout.writefln("// if stack %-(%s, %)", ctx.stack);
                        set_local(ctx.current);
                        const else_indent = indent[0 .. $ - spacer.length];
                        bout.writefln("%s}", else_indent);
                        bout.writefln("%selse {", else_indent);
                        break;
                    case BRANCH:
                        switch (elm.code) {
                        case IR.BR:
                            const lth = elm.warg.get!uint;
                            check(lth < ctx.number_of_blocks, format(
                                    "Label number of %d exceeds the block stack for max %d",
                                    lth, ctx.number_of_blocks));
                            const target_index = ctx.index(lth);
                            auto target_block = ctx[target_index];
                            set_local(ctx.current);

                            if ((lth > 0) && !ctx.current.isVoidType) {
                                bout.writefln("%s%s = %s;", indent, target_block.block_result,
                                        ctx.current.block_result);
                            }

                            scope (exit) {
                                uint count;
                                while (!expr.empty && expr.front.code != IR.END) {
                                    expr.popFront;
                                    count++;
                                }
                            }
                            bout.writefln("%s// BR %d", indent, lth);
                            switch (ctx.current.kind) {
                            case BlockKind.LOOP:
                                if ((lth == 0) && (expr.front.code is IR.END)) {
                                    ctx.current.kind = BlockKind.DO_WHILE;
                                    break;
                                }
                                goto default;
                            default:
                                if (lth == 0) {
                                    break;
                                }
                                bout.writefln("%s;", indent, ctx.jump(target_block));
                            }
                            break;
                        case IR.BR_IF:
                            const lth = elm.warg.get!uint;
                            check(lth < ctx.number_of_blocks, format(
                                    "Label number of %d exceeds the block stack for max %d",
                                    lth, ctx.number_of_blocks));
                            const block_index = ctx.index(lth);
                            auto target_block = ctx[block_index];
                            const conditional_flag = ctx.pop;
                            set_local(ctx.current);
                            ctx.push(ctx.current);
                            if ((lth > 0) && !ctx.current.isVoidType) {
                                bout.writefln("%s%s = %s;", indent, target_block.block_result,
                                        ctx.current.block_result);
                            }
                            bout.writefln("%s// BR_IF %d", indent, lth);
                            if ((lth == 0) && (ctx.current.kind is BlockKind.LOOP)) {
                                ctx.current.condition = conditional_flag;
                                ctx.current.kind = BlockKind.WHILE;
                            }
                            bout.writefln("%sif (%s) %s;",
                                    indent, conditional_flag, ctx.jump(target_block));
                            break;
                        case IR.BR_TABLE:
                            auto br_table = elm.wargs.map!(w => w.get!uint);
                            scope (exit) {
                                uint count;
                                while (!expr.empty && expr.front.code != IR.END) {
                                    bout.writefln("%s// %d %s", indent, count, *(expr.front.instr));
                                    expr.popFront;
                                    count++;
                                }
                            }

                            //auto current_block = ctx.current;
                            bout.writefln("// Stack %-(%s, %)", ctx.stack);
                            const switch_select = ctx.pop;
                            set_local(ctx.current);
                            ctx.push(ctx.current);
                            bout.writefln("%sswitch(%s) {", indent, switch_select);
                            scope (exit) {
                                bout.writefln("%s}", indent);
                            }

                            const local_indent = indent ~ spacer;

                            foreach (jump_idx, block_label_depth; br_table.enumerate) {

                                if (jump_idx >= elm.wargs.length - 1) {
                                    bout.writefln("%sdefault:", indent);
                                }
                                else {
                                    bout.writefln("%scase %d: // %d",
                                            indent, jump_idx,
                                            block_label_depth);
                                }
                                const block_index = ctx.index(block_label_depth);
                                if ((block_label_depth > 0) && !ctx.current.isVoidType) {
                                    bout.writefln("%s%s = %s;", local_indent,
                                            ctx[block_index].block_result,
                                            ctx.current.block_result);
                                    bout.writefln("%sbreak %s;", local_indent, ctx.goto_label(
                                            block_index));
                                }
                                else {
                                    bout.writefln("%s// empty", local_indent);
                                }

                            }
                            break;
                        default:
                            assert(0, format("Illegal branch command %s", elm.code));
                        }
                        break;
                    case CALL:
                        scope (exit) {
                            calls++;
                        }
                        bout.writefln("%s// %s %s", indent, elm.instr.name, elm.warg.get!uint);
                        const func_idx = elm.warg.get!uint;
                        const type_idx = wasmstream.get!(Section.FUNCTION)[func_idx].idx;
                        const function_header = wasmstream.get!(Section.TYPE)[type_idx];
                        __write("//call stack %-(%s, %)", ctx.stack);
                        const function_call = format("%s(%-(%s,%))",
                                function_name(func_idx), ctx.pops(function_header.params.length));
                        string set_result;
                        if (function_header.results.length) {
                            set_result = format("const %s=", result_name);
                            ctx.push(result_name);
                        }
                        bout.writefln("%s%s%s;", indent, set_result, function_call);
                        break;
                    case CALL_INDIRECT:
                        bout.writefln("%s%s (type %d)", indent, elm.instr.name, elm.warg.get!uint);
                        break;
                    case LOCAL:
                        bout.writefln("%s// %s %d", indent, elm.instr.name, elm.warg.get!uint);
                        switch (elm.code) {
                        case IR.LOCAL_TEE:
                            break;
                        case IR.LOCAL_GET:
                            const local_idx = elm.warg.get!uint;

                            ctx.get(local_idx);
                            break;
                        case IR.LOCAL_SET:
                            const local_idx = elm.warg.get!uint;
                            bout.writefln("%s%s=%s;", indent, ctx.local_names[local_idx], ctx.peek);
                            ctx.set(local_idx);
                            // 
                            break;
                        default:
                            assert(0, "Illegal local instruction");
                        }
                        break;
                    case GLOBAL:
                        bout.writefln("%s%s %d", indent, elm.instr.name, elm.warg.get!uint);
                        break;
                    case MEMORY:
                        bout.writefln("%s%s%s", indent, elm.instr.name, offsetAlignToString(
                                elm.wargs));
                        break;
                    case MEMOP:
                        bout.writefln("%s%s", indent, elm.instr.name);
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
                        bout.writefln("%s// %s %s", indent, elm.instr.name, value);
                        ctx.push(value);
                        break;
                    case END:
                        if (ctx.number_of_blocks) {
                            auto block = ctx.current;
                            if (block.elm.code is IR.LOOP) {
                                set_local(block);

                            }
                        }
                        return;
                    case ILLEGAL:
                        bout.writefln("Error: Illegal instruction %02X", elm.code);
                        break;
                    case SYMBOL:
                        assert(0, "Symbol opcode and it does not have an equivalent opcode");
                    }
                }
            }
        }

        auto bout = new OutBuffer;
        scope (exit) {
            output.write(bout.toString);
            if (!no_return && (ctx.stack.length >= func_type.results.length)) {
                output.writefln("%sreturn %s;", indent, results_value);
            }
        }
        auto expr_list = expr;
        //bout.writefln("// List %s", expr_list.map!(e => e.code));
        innerBlock(bout, expr, indent);
    }

    Output serialize() {
        output.writefln("module %s;", module_name);
        output.writeln;
        imports.each!(imp => output.writefln("import %s;", imp));
        attributes.each!(attr => output.writefln("%s:", attr));
        //indent = spacer;
        scope (exit) {
            output.writeln("// end ---");
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
        //
        IR.IF: q{(%1$s)},
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
