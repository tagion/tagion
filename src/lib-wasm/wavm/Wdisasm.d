module wavm.Wdisasm;

import std.format;
import std.stdio;
import std.traits : EnumMembers;
import std.typecons : Tuple;
import std.uni : toLower;
import std.conv : to;
import std.range.primitives : isOutputRange;
import std.range : StoppingPolicy, lockstep;

import wavm.Wasm;

struct Wdisasm {
    protected Wasm wasm;
    @disable this();
    this(const Wasm wasm) {
        this.wasm=wasm;
    }
    static bool simple_error(const bool flag, string text) {
        if (!flag) {
            stderr.writeln("Error %s", text);
        }
        return flag;
    }

    alias WasmSection=Wasm.WasmRange.WasmSection;
    alias Section=Wasm.Section;

    protected static string secname(immutable Section s) {
        import std.exception : assumeUnique;
        return assumeUnique(format("%s_sec", toLower(s.to!string)));
    }


    alias Module=Tuple!(
        const(WasmSection.Custom)[],  secname(Section.CUSTOM),
        const(WasmSection.Type)*,     secname(Section.TYPE),
        const(WasmSection.Import)*,   secname(Section.IMPORT),
        const(WasmSection.Function)*, secname(Section.FUNCTION),
        const(WasmSection.Table)*,    secname(Section.TABLE),
        const(WasmSection.Memory)*,   secname(Section.MEMORY),
        const(WasmSection.Global)*,   secname(Section.GLOBAL),
        const(WasmSection.Export)*,   secname(Section.EXPORT),
        const(WasmSection.Start)*,    secname(Section.START),
        const(WasmSection.Element)*,  secname(Section.ELEMENT),
        const(WasmSection.Code)*,     secname(Section.CODE),
        const(WasmSection.Data)*,     secname(Section.DATA),
        );

    alias ModuleIterator=void delegate(const Section sec, ref scope const(Module) mod);

    interface InterfaceModule {
        void custom_sec(ref scope const(Module) mod);
        void type_sec(ref scope const(Module) mod);
        void import_sec(ref scope const(Module) mod);
        void function_sec(ref scope const(Module) mod);
        void table_sec(ref scope const(Module) mod);
        void memory_sec(ref scope const(Module) mod);
        void global_sec(ref scope const(Module) mod);
        void export_sec(ref scope const(Module) mod);
        void start_sec(ref scope const(Module) mod);
        void element_sec(ref scope const(Module) mod);
        void code_sec(ref scope const(Module) mod);
        void data_sec(ref scope const(Module) mod);
    }

    shared static unittest {
        template NoPtr(T) {
            T x;
            alias NoPtr=typeof(x[0]);
        }


        import std.traits : Unqual;
        import std.meta : staticMap;
        alias NoPtrModule=staticMap!(NoPtr, Module.Types);
        alias unqualModule=staticMap!(Unqual, NoPtrModule);
        static assert(is(unqualModule == WasmSection.Sections));
    }

    void opCall(T)(T iter) if (is(T==ModuleIterator) || is(T:InterfaceModule)) {
        scope Module mod;
        Wasm.Section previous_sec;
        foreach(a; wasm[]) {
            with(Wasm.Section) {
                if ((a.section !is CUSTOM) && (simple_error(previous_sec < a.section, "Bad order"))) {
                    previous_sec=a.section;
                    final switch(a.section) {
                        foreach(E; EnumMembers!(Wasm.Section)) {
                        case E:
                            static if (E is CUSTOM) {
                                mod.custom_sec~=a.sec!CUSTOM;
                            }
                            else {
                                const sec=a.sec!E;
                                mod[E]=&sec;
                            }
                            static if (is(T==ModuleIterator)) {
                                iter(a.section, mod);
                            }
                            else {
                                enum code=format(q{iter.%s(mod);}, secname(E));
                                pragma(msg, code);
                                mixin(code);
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}


WastT!Output Wast(Output)(Wdisasm dasm, Output output) {
    return new WastT!Output(dasm, output);
}

class WastT(Output) : Wdisasm.InterfaceModule {
    alias Module=Wdisasm.Module;
    alias ExprRange=Wasm.WasmRange.WasmSection.ExprRange;
    alias WasmArg=Wasm.WasmRange.WasmSection.WasmArg;
    alias Section=Wasm.Section;
    alias IRType=Wasm.IRType;
    alias IR=Wasm.IR;
    alias Types=Wasm.Types;
    alias typesName=Wasm.typesName;
    alias indexName=Wasm.indexName;
    alias ImportType=Wasm.WasmRange.WasmSection.ImportType;
    alias IndexType=Wasm.IndexType;
    alias Mutable=Wasm.Mutable;
    alias Limit=Wasm.Limit;
    alias GlobalDesc=Wasm.WasmRange.WasmSection.ImportType.ImportDesc.GlobalDesc;

    protected {
        Output output;
        Wdisasm dasm;
        string indent;
        string spacer;
    }

    this(Wdisasm dasm, Output output, string spacer="  ") { //static if (isOutputRange!Ouput) {
        this.output=output;
        this.dasm=dasm;
        this.spacer=spacer;
    }

    static string limitToString(ref const Limit limit) {
        immutable to_range=(limit.lim is Wasm.Limits.INFINITE)?"":format(" %d", limit.to);
        return format("%d%s", limit.from, to_range);
    }

    static string globalToString(ref const GlobalDesc globaldesc) {
        with(Mutable) {
            final switch(globaldesc.mut) {
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
        const _offset=wargs[0].get!uint;
        const _align=wargs[1].get!uint;

        if (_offset > 0) {
            result~=format(" offset=%d", _offset);
        }
        if (_align > 0) {
            result~=format(" align=%d", _align);
        }
        return result;
    }

    void custom_sec(ref scope const(Module) mod) {
    }

    void type_sec(ref scope const(Module) mod) {
        auto _type=*mod.type_sec;
        foreach(t; _type[]) {
            output.writef("%s(type (%s", indent, typesName(t.type));
            if (t.params.length) {
                output.write(" (param");
                foreach(p; t.params) {
                    output.writef(" %s", typesName(p));
                }
                output.write(")");
            }
            if (t.results.length) {
                output.write(" (result");
                foreach(r; t.results) {
                    output.writef(" %s", typesName(r));
                }
                output.write(")");
            }
            output.writeln("))");
        }
    }

    void import_sec(ref scope const(Module) mod) {
        auto _import=*mod.import_sec;
        static string importdesc(ref const ImportType imp) {
            const desc=imp.importdesc.desc;
            with(IndexType) {
                final switch(desc) {
                case FUNC:
                    const _funcdesc=imp.importdesc.get!FUNC;
                    return format("(%s (type %d))", indexName(desc), _funcdesc.typeidx);
                case TABLE:
                    const _tabledesc=imp.importdesc.get!TABLE;
                    return format("(%s %s %s)", indexName(desc), limitToString(_tabledesc.limit), typesName(_tabledesc.type));
                case MEMORY:
                    const _memorydesc=imp.importdesc.get!MEMORY;
                    return format("(%s %s %s)", indexName(desc), limitToString(_memorydesc.limit));
                case GLOBAL:
                    const _globaldesc=imp.importdesc.get!GLOBAL;
                    return format("(%s %s)", indexName(desc), globalToString(_globaldesc));
                }
            }
        }
        foreach(imp; _import[]) {
//            output.writefln("imp=%s", imp);
            output.writefln(`%s(import "%s" "%s" %s)`,
                indent, imp.mod, imp.name, importdesc(imp));
        }
    }

    void function_sec(ref scope const(Module) mod) {
        // Empty
    }

    void table_sec(ref scope const(Module) mod) {
        auto _table=*mod.table_sec;
        foreach(t; _table[]) {
            output.writefln("%s(table %s %s)", indent, limitToString(t.limit), typesName(t.type));
        }
    }

    void memory_sec(ref scope const(Module) mod) {
        auto _memory=*mod.memory_sec;
        foreach(m; _memory[]) {
            output.writefln("%s(memory %s)", indent, limitToString(m.limit));
        }
    }

    void global_sec(ref scope const(Module) mod) {
        auto _global=*mod.global_sec;
        foreach(g; _global[]) {
            output.writefln("%s(global %s", indent, globalToString(g.global));
            auto expr=g[];
            block(expr, indent~spacer);
            output.writefln("%s)", indent);
        }
    }

    void export_sec(ref scope const(Module) mod) {
        auto _export=*mod.export_sec;
        foreach(exp; _export[]) {
            output.writefln(`%s(export "%s" (%s %d))`, indent, exp.name, indexName(exp.desc), exp.idx);
        }

    }

    void start_sec(ref scope const(Module) mod) {
        output.writefln("%s(start %d),", indent, mod.start_sec.idx);
    }

    void element_sec(ref scope const(Module) mod) {
        auto _element=*mod.element_sec;
        foreach(e; _element[]) {
            output.writefln("%s(elem (", indent);
            auto expr=e[];
            const local_indent=indent~spacer;
            block(expr, local_indent~spacer);
            output.writef("%s) func", local_indent);
            foreach(f; e.funcs) {
                output.writef(" %d", f);
            }
            output.writeln(")");
        }
    }

    void code_sec(ref scope const(Module) mod) {
        auto _code=*mod.code_sec;
        auto _func=*mod.function_sec;
        writefln("code.data=%s", _code.data);

        foreach(f, c; lockstep(_func[], _code[], StoppingPolicy.requireSameLength)) {
            auto expr=c[];
            //writefln(">c.data=%s", c.data);
            //writefln(">c.locals.data=%s c.locals.length=%d", c.locals.data, c.locals.length);
            output.writefln("%s(func (type %d)", indent, f.idx);
            const local_indent=indent~spacer;
            if (!c.locals.empty) {
                output.writef("%s(local", local_indent);
                foreach(l; c.locals) {
                    output.writef(" %s", typesName(l.type));
                }
                output.writeln(")");
            }

            block(expr, local_indent);
            output.writefln("%s)", indent);
        }
    }

    void data_sec(ref scope const(Module) mod) {
    }

    private const(ExprRange.IRElement) block(ref ExprRange expr, const(string) indent, const uint level=0) {
            string block_comment;
            uint block_count;
            uint count;
            while (!expr.empty) {
                const elm=expr.front;
                const instr=Wasm.instrTable[elm.code];
                expr.popFront;
                with(IRType) {
                    final switch(instr.irtype) {
                    case CODE:
                        output.writefln("%s%s", indent, instr.name);
                        break;
                    case BLOCK:
                        static string block_result_type() (const Types t) {
                            with(Types) {
                                switch(t) {
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
                        block_comment=format(";; block %d", block_count);
                        block_count++;
                        output.writefln("BLOCK %s", elm);
                        output.writefln("%s%s%s %s", indent, instr.name, block_result_type(elm.types[0]), block_comment);
                        const end_elm=block(expr, indent~spacer, level+1);
                        const end_instr=Wasm.instrTable[end_elm.code];
                        output.writefln("%send %s count=%d", indent, block_comment, count);
                        break;
                    case BRANCH:
                        output.writefln("%s%s %s", indent, instr.name, elm.warg.get!uint);
                        break;
                    case BRANCH_TABLE:
                        static string branch_table(const(WasmArg[]) args) pure {
                            string result;
                            foreach(a; args) {
                                result~=format(" %d", a.get!uint);
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
                        output.writefln("%s%s %d", indent, instr.name, elm.warg.get!uint);
                        break;
                    case GLOBAL:
                        output.writefln("%s%s %d", indent, instr.name, elm.warg.get!uint);
                        break;
                    case MEMORY:
                        output.writefln("%s%s%s", indent, instr.name, offsetAlignToString(elm.wargs));
                        break;
                    case MEMOP:
                        output.writefln("%s[%s] ;; %s", indent, instr.name, elm);
                        break;
                    case CONST:
                        static string toText(const WasmArg a) {
                            with(Types) {
                                switch(a.type) {
                                case I32:
                                    return a.get!int.to!string;
                                case I64:
                                    return a.get!long.to!string;
                                case F32:
                                    const x=a.get!float;
                                    return format("%a ;; %s", x, x);
                                case F64:
                                    const x=a.get!double;
                                    return format("%a ;; %s", x, x);
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
                    }
                }
            }
            return ExprRange.IRElement(IR.END, level);
        }

    Output serialize() {
        output.writeln("(module");
        indent=spacer;
        scope(exit) {
            output.writeln(")");
        }
        dasm(this);
        return output;
    }
}

unittest {
    import std.stdio;
    import std.file;
    import std.exception : assumeUnique;
    //      import std.file : fread=read, fwrite=write;


    @trusted
        static immutable(ubyte[]) fread(R)(R name, size_t upTo = size_t.max) {
        import std.file : _read=read;
        auto data=cast(ubyte[])_read(name, upTo);
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
    string filename="../tests/wasm/elem_1.wasm";
    immutable code=fread(filename);
    auto wasm=Wasm(code);
    auto dasm=Wdisasm(wasm);
    Wast(dasm, stdout).serialize();
//    auto output=Wast

}

/+
[
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
4, 1, 1, 127, 11,
4, 1, 1, 127, 11,
8, 3, 1, 127, 1, 124, 1, 126, 11,
6, 2, 1, 127, 1, 124, 11,
12, 5, 1, 127, 1, 125, 1, 126, 1, 127, 1, 124, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
3, 0, 0, 11,
2, 0, 11,
4, 0, 65, 0, 11,
2, 0, 11, 4, 0, 65, 0, 11,
4, 0, 65, 0, 11, 2, 0, 11,
4, 0, 65, 0, 11, 2, 0, 11,
2, 0, 11,
16, 6, 1, 125, 1, 127, 1, 126, 1, 127, 1, 124, 1, 127, 0, 0, 11,
16, 6,
1, 125,
1, 127,
1, 126,
1, 127,
1, 124,
1, 127,
0, 0, 11,

6, 1,
2, 127,
32, 0,
11,

6, 1, 2, 126, 32, 0, 11,
6, 1, 2, 125, 32, 0, 11,
6, 1, 2, 124, 32, 0, 11,
6, 1, 2, 127, 32, 1, 11,
6, 1, 2, 126, 32, 1, 11,
6, 1, 2, 125, 32, 1, 11,
6, 1, 2, 124, 32, 1, 11,
40, 6, 1, 125, 1, 127, 1, 126, 1, 127, 1, 124, 1, 127, 32, 0, 140, 26, 32, 1, 69, 26, 32, 2, 80, 26, 32, 3, 69, 26, 32, 4, 154, 26, 32, 5, 69, 26, 32, 4, 11,
4, 0, 32, 0, 11,
4, 0, 32, 0, 11,
4, 0, 32, 0, 11,
4, 0, 32, 0, 11,
4, 0, 32, 1, 11,
4, 0, 32, 1, 11,
4, 0, 32, 1, 11,
4, 0, 32, 1, 11,
28, 0, 32, 0, 140, 26, 32, 1, 69, 26, 32, 2, 80, 26, 32, 3, 69, 26, 32, 4, 154, 26, 32, 5, 69, 26, 32, 4, 11,
2, 0, 11,
4, 0, 16, 0, 11,
5, 0, 65, 205, 0, 11, 5, 0, 66, 225, 60, 11,
7, 0, 67, 102, 102, 155, 66, 11,
11, 0, 68, 225, 122, 20, 174, 71, 113, 83, 64, 11,
9, 0, 2, 64, 16, 0, 16, 0, 11, 11,
10, 0, 2, 127, 16, 0, 65, 205, 0, 11, 11,
3, 0, 15, 11,
6, 0, 65, 206, 0, 15, 11,
6, 0, 66, 198, 61, 15, 11,
8, 0, 67, 102, 102, 157, 66, 15, 11,
12, 0, 68, 82, 184, 30, 133, 235, 177, 83, 64, 15, 11,
11, 0, 2, 127, 16, 0, 65, 205, 0, 11,
15, 11, 4, 0, 12, 0, 11, 7, 0, 65, 207, 0, 12, 0, 11,
7, 0, 66, 171, 62, 12, 0, 11,
9, 0, 67, 205, 204, 159, 66, 12, 0, 11,
13, 0, 68, 195, 245, 40, 92, 143, 242, 83, 64, 12, 0, 11,
12, 0, 2, 127, 16, 0, 65, 205, 0, 11,
12, 0, 11, 6, 0, 32, 0, 13, 0, 11,
11, 0, 65, 50, 32, 0, 13, 0, 26, 65, 51, 11,
9, 0, 32, 0, 14, 2, 0, 0, 0, 11,
12, 0, 65, 50, 32, 0, 14, 1, 0, 0, 65, 51, 11,
12, 0, 2, 64, 32, 0, 14, 2, 0, 1, 0, 11,
11, 19, 0, 2, 127, 65, 50, 32, 0, 14, 2, 0, 1, 0, 65, 51, 11,
65, 2, 106, 11, 6, 1, 1, 127, 32, 0, 11, 6, 1, 1, 126, 32, 0, 11, 6, 1, 1, 125, 32, 0, 11, 6, 1, 1, 124, 32, 0, 11
]
+/
