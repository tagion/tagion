module tagion.wasm.WasmWat;

import std.conv : to;
import std.format;
import std.range : StoppingPolicy, enumerate, lockstep;
import std.range : isOutputRange, take;
import std.stdio;
import std.traits : ConstOf, EnumMembers, ForeachType, PointerTarget;
import std.typecons : Tuple;
import std.algorithm;
import std.uni : toLower;
import tagion.errors.tagionexceptions;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmException;
import tagion.wasm.WasmReader;
import tagion.basic.Debug;

@safe class WatException : WasmException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!WatException;

@safe WatT!(Output) wat(Output)(WasmReader wasmreader, Output output) {
    return new WatT!(Output)(wasmreader, output);
}

@safe class WatT(Output) : WasmReader.InterfaceModule {
    alias Sections = WasmReader.Sections;
    //alias ExprRange=WasmReader.WasmRange.WasmSection.ExprRange;
    //alias WasmArg=WasmReader.WasmRange.WasmSection.WasmArg;
    alias ImportType = WasmReader.WasmRange.WasmSection.ImportType;
    alias Limit = WasmReader.Limit;
    alias GlobalDesc = WasmReader.WasmRange.WasmSection.ImportType.ImportDesc.GlobalDesc;

    protected {
        Output output;
        WasmReader wasmstream;
        string indent;
        string spacer;
    }

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

    alias Custom = Sections[Section.CUSTOM];
    void custom_sec(ref scope const(Custom) _custom) {
        output.writef(`%s(custom "%s" `, indent, _custom.name);
        enum {
            SPACE = 32,
            DEL = 127
        }
        import tagion.hibon.Document;
        import tagion.hibon.HiBONJSON;
        import LEB128 = tagion.utils.LEB128;
        import std.algorithm;

        if (_custom.doc.isInorder) {
            output.writefln("\n%s", _custom.doc.toPretty);
            output.writefln(`)`);
        }
        else {
            output.write(`"`);
            foreach (d; _custom.bytes) {
                if ((d > SPACE) && (d < DEL)) {
                    output.writef(`%c`, char(d));
                }
                else {
                    output.writef(`\x%02X`, d);
                }
            }
            output.writefln(`")`);
        }
    }

    alias Type = Sections[Section.TYPE];
    void type_sec(ref const(Type) _type) {
        //        auto _type=*mod[Section.TYPE]; //type_sec;
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
        // The functions headers are printed in the code section
        this._function = cast(Function) _function;
    }

    alias Table = Sections[Section.TABLE];
    void table_sec(ref const(Table) _table) {
        //        auto _table=*mod[Section.TABLE];
        foreach (i, t; _table[].enumerate) {
            output.writefln("%s(table (;%d;) %s %s)", indent, i,
                    limitToString(t.limit), typesName(t.type));
        }
    }

    alias Memory = Sections[Section.MEMORY];
    void memory_sec(ref const(Memory) _memory) {
        //        auto _memory=*mod[Section.MEMORY];
        foreach (i, m; _memory[].enumerate) {
            output.writefln("%s(memory (;%d;) %s)", indent, i, limitToString(m.limit));
        }
    }

    alias Global = Sections[Section.GLOBAL];
    void global_sec(ref const(Global) _global) {
        //        auto _global=*mod[Section.GLOBAL];
        foreach (i, g; _global[].enumerate) {
            output.writefln("%s(global (;%d;) %s (", indent, i, globalToString(g.global));
            auto expr = g[];
            block(expr, indent ~ spacer);
            output.writefln("%s))", indent);
        }
    }

    alias Export = Sections[Section.EXPORT];
    void export_sec(ref const(Export) _export) {
        //        auto _export=*mod[Section.EXPORT];
        foreach (exp; _export[]) {
            output.writefln(`%s(export "%s" (%s %d))`, indent, exp.name,
                    indexName(exp.desc), exp.idx);
        }

    }

    alias Start = Sections[Section.START];
    void start_sec(ref const(Start) _start) {
        output.writefln("%s(start %d),", indent, _start.idx);
    }

    alias Element = Sections[Section.ELEMENT];
    void element_sec(ref const(Element) _element) {
        //        auto _element=*mod[Section.ELEMENT];
        foreach (i, e; _element[].enumerate) {
            output.writefln("%s(elem (;%d;) (", indent, i);
            auto expr = e[];
            const local_indent = indent ~ spacer;
            block(expr, local_indent ~ spacer);
            output.writef("%s) func", local_indent);
            foreach (f; e.funcs) {
                output.writef(" %d", f);
            }
            output.writeln(")");
        }
    }

    alias Code = Sections[Section.CODE];
    @trusted void code_sec(ref const(Code) _code) {
        check(_function !is null, "Function section missing");
        check(_code !is null, "Code section missing");
        foreach (f, c; lockstep(_function[], _code[], StoppingPolicy.requireSameLength)) {
            auto expr = c[];
            output.writefln("%s(func (type %d)", indent, f.idx);
            const local_indent = indent ~ spacer;
            if (!c.locals.empty) {
                output.writef("%s(local", local_indent);
                foreach (l; c.locals) {
                    foreach (i; 0 .. l.count) {
                        output.writef(" %s", typesName(l.type));
                    }
                }
                output.writeln(")");
            }
            block(expr, local_indent);
            output.writefln("%s)", indent);
        }
    }

    alias Data = Sections[Section.DATA];
    void data_sec(ref const(Data) _data) {
        foreach (idx, d; _data[].enumerate) {
            output.writefln("%s", d);
            output.writef("%s(data (;%d;) ", indent, idx);
            final switch (d.mode) {
            case DataMode.ACTIVE_INDEX:
                goto case;
            case DataMode.ACTIVE:
                output.write(" (");
                auto expr = d[];
                const local_indent = indent ~ spacer;
                block(expr, local_indent ~ spacer);
                output.writef("%s)", local_indent);
                break;
            case DataMode.PASSIVE:
                output.writef("(memory %d)", d.memidx);
            }
            output.writefln(` "%s")`, d.base);
        }
    }

    version (none) string typeName(ref const ExprRange.IRElement elm) {
        if (elm.argtypes is ExprRange.IRElement.IRArgType.TYPES) {
            return typeName(elm.types);
        }
        return typeName(wasmstream.get!(Section.TYPE)[elm.idx].results);

    }

    private const(ExprRange.IRElement) block(ref ExprRange expr,
            const(string) indent, const uint level = 0) {
        //        immutable indent=base_indent~spacer;
        string block_comment;
        uint block_count;
        uint count;
        string block_result_type()(const ref ExprRange.IRElement elm) {
            with (ExprRange.IRElement.IRArgType) {
                assert(elm.argtype is TYPES || elm.argtype is INDEX,
                        "Invalid block type");
                if (elm.argtype is INDEX) {
                    const sec_type = wasmstream.get!(Section.TYPE);
                    const func_type = sec_type[elm.idx];
                    return format(" (result %-(%s %))",
                            func_type.results.map!(r => typesName(r)));
                }
            }
            with (Types) {
                switch (elm.types[0]) {
                case I32, I64, F32, F64, FUNCREF:
                    return format(" (result %s)", typesName(elm.types[0]));
                case VOID:
                    return null;
                default:
                    check(0, format("Block Illegal result type %s for a block", elm.types[0]));
                }
            }
            assert(0);
        }

        while (!expr.empty) {
            const elm = expr.front;
            expr.popFront;
            with (IRType) {
                final switch (elm.instr.irtype) {
                case CODE:
                case CODE_EXTEND:
                case CODE_TYPE:
                case OP_STACK:
                case RETURN:
                    output.writefln("%s%s", indent, elm.instr.name);
                    break;
                case PREFIX:
                    output.writefln("%s%s", indent, elm.instr.name);
                    break;
                case BLOCK_CONDITIONAL:
                case BLOCK:
                    block_comment = format(";; block %d", block_count);
                    block_count++;
                    output.writefln("%s%s%s %s", indent, elm.instr.name,
                            block_result_type(elm), block_comment);
                    const end_elm = block(expr, indent ~ spacer, level + 1);
                    const end_instr = instrTable[end_elm.code];
                    output.writefln("%s%s", indent, end_instr.name);
                    break;
                case BLOCK_ELSE:
                    const endif_elm = block(expr, indent ~ spacer, level);
                    const endif_instr = instrTable[endif_elm.code];
                    output.writefln("%s%s %s count=%d", indent,
                            endif_instr.name, block_comment, count);
                    break;
                case BRANCH:
                    if (elm.code is IR.BR_TABLE) {
                        static string branch_table(const(WasmArg[]) args) {
                            string result;
                            foreach (a; args) {
                                result ~= format(" %d", a.get!uint);
                            }
                            return result;
                        }

                        output.writefln("%s%s %s", indent, elm.instr.name, branch_table(elm.wargs));
                        break;
                    }
                    output.writefln("%s%s %s", indent, elm.instr.name, elm.warg.get!uint);
                    break;
                case CALL:
                    output.writefln("%s%s %s", indent, elm.instr.name, elm.warg.get!uint);
                    break;
                case CALL_INDIRECT:
                    output.writefln("%s%s (type %d)", indent, elm.instr.name, elm.warg.get!uint);
                    break;
                case LOCAL:
                    output.writefln("%s%s %d", indent, elm.instr.name, elm.warg.get!uint);
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

                    output.writefln("%s%s %s", indent, elm.instr.name, toText(elm.warg));
                    break;
                case END:
                    return elm;
                case ILLEGAL:
                    throw new WatException(format("Illegal instruction %02X", elm.code));
                case SYMBOL:
                    assert(0, "Symbol opcode and it does not have an equivalent opcode");
                }
            }
        }
        return ExprRange.IRElement(IR.END, level);
    }

    Output serialize() {
        output.writeln("(module");
        indent = spacer;
        scope (exit) {
            output.writeln(")");
        }
        wasmstream(this);
        return output;
    }
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
    Wat(wasm, stdout).serialize();
    //    auto output=Wat

}
