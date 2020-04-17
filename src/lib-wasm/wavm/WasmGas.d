module wavm.WasmGas;

import std.outbuffer;
import wavm.WasmWriter;
import wavm.WasmBase;
import wavm.WasmExpr;
import wavm.LEB128;
import std.traits : Unqual, TemplateArgsOf, PointerTarget, EnumMembers;
import std.meta : staticMap;

struct WasmGas {
    enum set_gas_gauge="$set_gas_gauge";
    enum read_gas_gauge="$read_gas_gauge";
    protected WasmWriter writer;

    this(ref WasmWriter writer) {
        this.writer=writer;
    }

    alias GlobalDesc=WasmWriter.WasmSection.ImportType.ImportDesc.GlobalDesc;
    alias Global=WasmWriter.WasmSection.Global;
    alias Type=WasmWriter.WasmSection.Type;
    alias FUnction=WasmWriter.WasmSection.Function;
    alias Code=WasmWriter.WasmSection.Code;
    alias GlobalType=WasmWriter.WasmSection.GlobalType;
    alias FuncType=WasmWriter.WasmSection.FuncType;
    alias Index=WasmWriter.WasmSection.Index;
    alias CodeType=WasmWriter.WasmSection.CodeType;
    alias ExportType=WasmWriter.WasmSection.ExportType;

    uint inject(SecType)(SecType sectype) {
        uint idx;
        enum SectionId=WasmWriter.fromSecType!SecType;
        if (writer.mod[SectionId] is null) {
            idx=0;
            writer.mod[SectionId]=new WasmWriter.WasmSection.SectionT!SecType;
            writer.mod[SectionId].sectypes=[sectype];
        }
        else {
            idx=cast(uint)(writer.mod[SectionId].sectypes.length);
            writer.mod[SectionId].sectypes~=sectype;
        }
        return idx;
    }

    /+
    package void inject_gas(const uint gas_counter_funcidx) {
        auto code_sec=mod[Section.CODE];
        static void inject_gas(scope OutBuffer bout, const uint gas) {
            wasmexpr
                (IR.I32_CONST, gas)
                (IR.CALL, gas_counter_funcidx);
        }

        uint inject_gas_funcs(ref scope OutBuffer bout, ref ExprRange expr, const uint level) {
            scope wasmexpr=WasmExpr(bout);
            uint gas_count;
            while(!expr.empty) {
                const elm=expr.front;
                const instr=instrTable[elm.code];
                gas_count+=instr.cost;
                expr.popFront;
                with(IRType) {
                    final switch(irstr.irtype) {
                    case CODE:
                        waspexpr(elm.code);
                        //bout.write(cast(ubyte)elm.code);
                        break;
                    case BLOCK:
                        wasmexpr(elm.code, elm.types[0]);
                        scope block_bout=new OutBuffer;
                        pragma(msg, "fixme(cbr): add block_bout.reserve");
                        const block_gas_cost=inject_gas_funcs(but, expr, eml.level);
                        inject_gas(bout, block_gas_cost);
                        bout.write(block_bout);
                        break;
                    case BRANCH:
                        wasmexpr(elm.code, elm.warg.get!uint);
                        break;
                    case BRANCH_TABLE:
                        const branch_idxs=elm.wargs.each((a) => a.get!uint).array;
                        wasmexpr(elm.code, branch_idxs);
                        break;
                    case CALL, LOCAL, GLOBAL, CALL_INDIRECT:
                        wasmexpr(elm.code, elm.warg.get!uint);
                        break;
                    case MEMORY:
                        wasmexpr(elm.code, elm.warg[0].get!uint, elm.warg[1].get!uint);
                        break;
                    case MEMOP:
                        wasmexpr(elm.code);
                        break;
                    case CONST:
                        with(IR) {
                            switch (elm.code) {
                            case I32_CONST:
                                wasmexpr(elm.code, elm.warg.get!int);
                                break
                            case I64_CONST:
                                wasmexpr(elm.code, elm.warg.get!long);
                                break
                            case F32_CONST:
                                wasmexpr(elm.code, elm.warg.get!float);
                                break
                            case F64_CONST:
                                wasmexpr(elm.code, elm.warg.get!double);
                                break;
                            default:
                                assert(0, format("Instruction %s is not a const", elm.code));
                            }
                        }
                    case END:
                        if (level == elm.level) {
                            expr=ExprRan
                            return gas_count;
                        }
                    }
                }
            }
            return gas_const;
        }
        if (code_sec) {
            foreach(c; code_sec.opSlice) {
                scope expr_bout=new OutBuffer;
                expr_bout.re
            }
        }
    }
    +/
    void modify() {
        /+
         Inject the Global variable
         +/
        GlobalType global_type;
        {
            scope out_expr=new OutBuffer;
            WasmExpr(out_expr)(IR.I32_CONST, 0)(IR.END);
            GlobalDesc global_desc=GlobalDesc(Types.I32, Mutable.VAR);
            immutable expr=out_expr.toBytes.idup;
            global_type=GlobalType(global_desc, expr);
        }
        const global_idx=inject(global_type);
        const func_sec=writer.mod[Section.FUNCTION];
        const gas_count_func_idx=cast(uint)((func_sec is null)?0:func_sec.sectypes.length);


        { // Gas down counter
            FuncType func_type=FuncType(Types.FUNC, null, null);
            const type_idx=inject(func_type);

            Index func_index=Index(type_idx);
            const func_idx=inject(func_index);

            CodeType code_type;
            {
                scope out_expr=new OutBuffer;
                WasmExpr(out_expr)
                    (IR.GLOBAL_GET, global_idx)
                    (IR.I32_CONST, 0)
                    (IR.I32_GT_S)
                    (IR.IF, Types.EMPTY)
                    (IR.GLOBAL_GET, global_idx)
                    (IR.I32_CONST, 1)
                    (IR.I32_SUB)
                    (IR.GLOBAL_SET, global_idx)
                    (IR.ELSE)
                    (IR.UNREACHABLE)
                    (IR.END)
                    (IR.END);
                immutable expr=out_expr.toBytes.idup;
                code_type=CodeType(null, expr);
            }
            const code_idx=inject(code_type);
        }
        { // set_gas_gauge
            /+
             Inject the function type to the set_gas_gauge
             +/
            FuncType func_type=FuncType(Types.FUNC, [Types.I32], null);
            const type_idx=inject(func_type);
            /+
             Inject the function header index to the set_gas_gauge
             +/
            Index func_index=Index(type_idx); //Types.FUNC, [Types.I32], null);
            const func_idx=inject(func_index);
            /+
             Inject the function body to the set_gas_gauage
             +/
            CodeType code_type;
            {
                scope out_expr=new OutBuffer;
                WasmExpr(out_expr)
                    (IR.GLOBAL_GET, global_idx)
                    //       (IR.BLOCK)
                    (IR.I32_EQ)
                    (IR.IF, Types.EMPTY)
                    (IR.GLOBAL_SET, global_idx)
                    (IR.ELSE)
                    (IR.UNREACHABLE)
                    (IR.END)
                    (IR.END);
                immutable expr=out_expr.toBytes.idup;
                code_type=CodeType(null, expr);
            }
            const code_idx=inject(code_type);

            ExportType export_type=ExportType(set_gas_gauge, func_idx);
            const export_idx=inject(export_type);
        }
        { // read_gas_gauge
            FuncType func_type=FuncType(Types.FUNC, null, [Types.I32]);
            const type_idx=inject(func_type);

            Index func_index=Index(type_idx); //Types.FUNC, [Types.I32], null);
            const func_idx=inject(func_index);

            CodeType code_type;
            {
                scope out_expr=new OutBuffer;
                WasmExpr(out_expr)
                    (IR.GLOBAL_GET, global_idx)
                    (IR.END);
                immutable expr=out_expr.toBytes.idup;
                code_type=CodeType(null, expr);
            }
            const code_idx=inject(code_type);

            ExportType export_type=ExportType(read_gas_gauge, func_idx);
            const export_idx=inject(export_type);
        }
    }
}

unittest {
    import std.stdio;
    import std.file;
    import std.exception : assumeUnique;
    import wavm.Wast;
    import wavm.WasmReader;
    //      import std.file : fread=read, fwrite=write;


    @trusted
        static immutable(ubyte[]) fread(R)(R name, size_t upTo = size_t.max) {
        import std.file : _read=read;
        auto data=cast(ubyte[])_read(name, upTo);
        // writefln("read data=%s", data);
        return assumeUnique(data);
    }

//    string filename="../tests/wasm/func_1.wasm";
    string filename="../tests/wasm/global_1.wasm";
//    string filename="../tests/wasm/imports_1.wasm";
//    string filename="../tests/wasm/table_copy_2.wasm";
//    string filename="../tests/wasm/memory_2.wasm";
//    string filename="../tests/wasm/start_4.wasm";
//    string filename="../tests/wasm/address_1.wasm";
//    string filename="../tests/wasm/data_4.wasm";
//    string filename="../tests/web_gas_gauge.wasm";//wasm/imports_1.wasm";
    immutable read_data=fread(filename);
    auto wasm_reader=WasmReader(read_data);
    Wast(wasm_reader, stdout).serialize();
    //Wast(WasmReader(wasm_writer.serialize), stdout).serialize;

    //writefln("wasm_reader.serialize=%s", wasm_reader.serialize);
    auto wasm_writer=WasmWriter(wasm_reader);

    //writeln("wasm_writer.serialize");
    //writefln("wasm_writer.serialize=%s", wasm_writer.serialize);
    assert(wasm_reader.serialize == wasm_writer.serialize);
    auto wasmgas=WasmGas(wasm_writer);
    wasmgas.modify;
    {
        Wast(WasmReader(wasm_writer.serialize), stdout).serialize;
    }
}
