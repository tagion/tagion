module wavm.WasmGas;

import wavm.WasmWriter;
import wavm.WasmBase;
import wavm.WasmExpr;
import wavm.LEB128;

import std.traits : Unqual, TemplateArgsOf, PointerTarget, EnumMembers;
import std.meta : staticMap;
import std.outbuffer;
import std.typecons : Tuple;
import std.algorithm.comparison : max;
import std.algorithm.iteration : map;
import std.array : array;
import std.format;

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


    alias InjectGas=void delegate(scope OutBuffer bout, const uint gas);
    package void inject_gas(InjectGas inject_gas) { //const uint gas_counter_funcidx) {
        auto code_sec=writer.mod[Section.CODE];
        // void inject_gas(scope OutBuffer bout, const uint gas) {
        //     if (gas>0) {
        //         WasmExpr(bout)
        //             (IR.I32_CONST, gas)
        //             (IR.CALL, gas_counter_funcidx);
        //     }
        // }

        alias GasResult=Tuple!(uint, "gas", IR, "irtype");

        const(GasResult) inject_gas_funcs(ref scope OutBuffer bout, ref ExprRange expr) {
            scope wasmexpr=WasmExpr(bout);
            uint gas_count;
            while(!expr.empty) {
                const elm=expr.front;
                const instr=instrTable[elm.code];
                gas_count+=instr.cost;
                expr.popFront;
                with(IRType) {
                    final switch(instr.irtype) {
                    case CODE:
                        wasmexpr(elm.code);
                        break;
                    case BLOCK:
                        wasmexpr(elm.code, elm.types[0]);
                        scope block_bout=new OutBuffer;
                        pragma(msg, "fixme(cbr): add block_block_out.reserve");
                        const block_result=inject_gas_funcs(block_bout, expr);
                        if (elm.code is IR.IF) {
                            int if_gas_count=block_result.gas;
                            if (block_result.irtype is IR.ELSE) {
                                const endif_result=inject_gas_funcs(block_bout, expr);
                                if_gas_count=max(endif_result.gas, if_gas_count);
                            }
                            gas_count+=if_gas_count;
                        }
                        else {
                            inject_gas(bout, block_result.gas);
                        }
                        bout.write(block_bout);
                        break;
                    case BRANCH:
                        wasmexpr(elm.code, elm.warg.get!uint);
                        break;
                    case BRANCH_TABLE:
                        const branch_idxs=elm.wargs.map!((a) => a.get!uint).array;
                        wasmexpr(elm.code, branch_idxs);
                        break;
                    case CALL, LOCAL, GLOBAL, CALL_INDIRECT:
                        wasmexpr(elm.code, elm.warg.get!uint);
                        //writefln("\t\tdata=%s",
                        break;
                    case MEMORY:
                        wasmexpr(elm.code, elm.wargs[0].get!uint, elm.wargs[1].get!uint);
                        break;
                    case MEMOP:
                        wasmexpr(elm.code);
                        break;
                    case CONST:
                        with(IR) {
                            switch (elm.code) {
                            case I32_CONST:
                                wasmexpr(elm.code, elm.warg.get!int);
                                break;
                            case I64_CONST:
                                wasmexpr(elm.code, elm.warg.get!long);
                                break;
                            case F32_CONST:
                                wasmexpr(elm.code, elm.warg.get!float);
                                break;
                            case F64_CONST:
                                wasmexpr(elm.code, elm.warg.get!double);
                                break;
                            default:
                                assert(0, format("Instruction %s is not a const", elm.code));
                            }
                        }
                        break;
                    case END:
                        wasmexpr(elm.code);
                        return GasResult(gas_count, elm.code);
                    }
                }
            }
            return GasResult(gas_count, IR.END);
        }

        if (code_sec) {
//            int count=1;
            foreach(ref c; code_sec.sectypes) {
                // count--;
                // if (count < 0) {
                //     break;
                // }
                scope expr_bout=new OutBuffer;
                auto expr_range=c[];
//                 {
//                     auto expr=expr_range;
//                     // expr.test=true;
//                     // expr.count=10;
//                     foreach(e; expr) {
//                         writefln("::%s", e);
//                     }
// //                    writefln("ex
//                 }
//                writefln("expr_range.data=%s", expr_range.data);
                expr_bout.reserve(c.expr.length*5/4); // add 25%
                const gas_result=inject_gas_funcs(expr_bout, expr_range);
                scope code_bout=new OutBuffer;
                code_bout.reserve(expr_bout.offset+2*uint.sizeof);
                inject_gas(code_bout, gas_result.gas);
//                writefln("expr_bout=%s expr_range.empty=%s %s", expr_bout.toBytes, expr_range.empty, expr_range.front);
                code_bout.write(expr_bout);
                c.expr=code_bout.toBytes.idup;
//                writefln("code_bout=%s", code_bout.toBytes);
            }
        }
    }

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
        void inject_gas_count(scope OutBuffer bout, const uint gas) {
            if (gas>0) {
                WasmExpr(bout)
                    (IR.I32_CONST, gas)
                    (IR.CALL, gas_count_func_idx);
            }
        }
        inject_gas(&inject_gas_count); //gas_count_func_idx);

        { // Gas down counter
            FuncType func_type=FuncType(Types.FUNC, null, null);
            const type_idx=inject(func_type);

            Index func_index=Index(type_idx);
            const func_idx=inject(func_index);

            CodeType code_type;
            {
                scope out_expr=new OutBuffer;
                WasmExpr(out_expr)
                    (IR.LOCAL_SET, 0)
                    (IR.GLOBAL_GET, global_idx)
                    (IR.I32_CONST, 0)
                    (IR.I32_GT_S)
                    (IR.IF, Types.EMPTY)
                    (IR.GLOBAL_GET, global_idx)
                    (IR.LOCAL_GET, 0)
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
                    // void $set_gas_gauge(i32 $gas)
                    //   if ( $gas_gauge != 0) {
                    (IR.GLOBAL_GET, global_idx)(IR.I32_EQZ)(IR.IF, Types.EMPTY)
                    //       exit;
                    (IR.UNREACHABLE)
                    //   } else {
                    (IR.ELSE)
                    //     $gas_gauge=$gas;
                    (IR.GLOBAL_SET, global_idx)
                    //   }
                    (IR.END)
                    //}
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

version(none)
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
