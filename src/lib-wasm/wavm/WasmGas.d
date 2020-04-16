module wavm.WasmGas;

import std.outbuffer;
import wavm.WasmWriter;
import wavm.WasmBase;
import wavm.WasmExpr;
import wavm.LEB128;
import std.traits : Unqual, TemplateArgsOf, PointerTarget, EnumMembers;
import std.meta : staticMap;

struct WasmGas {
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


//     alias X=staticMap!(PointerTarget, WasmWriter.Module.Types);

//     alias XX=staticMap!(TemplateArgsOf, X); //staticMap!(PointerTarget, WasmWriter.Module.Types));
// //    enum X=Module.Types;

//     pragma(msg, "staticMap!(PointerTarget, Module.Types)=", WasmWriter.Module); //staticMap!(PointerTarget, Module.Types));
//     pragma(msg, "X=", X); //staticMap!(PointerTarget, Module.Types));
//     pragma(msg, "XX=", XX); //staticMap!(PointerTarget, Module.Types));
    // enum fromSecType(T)=WasmWriter.AsType(T, staticMap!(PointerTarget, Module.Types));
//    enum asType(T)=AsType!(T, staticMap!(PointerTarget, Module.Types));

    // template FromSecType(SecType, TList...) {
    //     alias T=WasmWriter.WasmSection.SectionT!SecType;
    //     static foreach(E; EnumMembers!Section) {
    //         static if (is(T == TList[E])) {
    //             enum FromSecType=E;
    //         }
    //     }
    // }

    // enum fromSecType(T)=FromSecType!(T, staticMap!(PointerTarget, WasmWriter.Module.Types));

//    pragma(msg, "fromSecType!GlobalType=", fromSecType!GlobalType);
    uint inject(SecType)(SecType sectype) {
        uint idx;
        enum SectionId=WasmWriter.fromSecType!SecType;
        pragma(msg, "SectionId=", SectionId); //, " SecType=", SecType);
        // version(none) {
        //enum SectionId=WasmWriter.fromSecType!SecType;
        // enum SectionId=fromSecType!SecType;
        // pragma(msg, "SectionId=", SectionId); //, " SecType=", SecType);
        //   pragma(msg, "SectionId=", SectionId, " SecType=", SecType);
        //pragma(msg, "Module.Types[SectionIn]=", Module.Types[SectionIn]);
        with(Section) {
            if (writer.mod[SectionId] is null) {
                idx=0;
                writer.mod[SectionId]=new WasmWriter.WasmSection.SectionT!SecType;
                writer.mod[SectionId].sectypes=[sectype];
            }
            else {
                idx=cast(uint)(writer.mod[SectionId].sectypes.length);
                writer.mod[SectionId].sectypes~=sectype;
            }
        }
        // }
        return idx;
    }

    pragma(msg, "asType ", WasmWriter.asType!(Global));

    void modify() {
        // const uint inject_global() {
        //     GlobalType global_type;
        //     {
        //         scope out_expr=new OutBuffer;
        //         WasmExpr(out_expr)(IR.I64_CONST, 0)(IR.END);
        //         GlobalDesc global_desc=GlobalDesc(Types.I64, Mutable.VAR);
        //         immutable expr=out_expr.toBytes.idup;
        //         global_type=GlobalType(global_desc, expr);
        //     }

        //     uint global_idx;
        //     with(Section) {
        //         if (writer.mod[GLOBAL] is null) {
        //             global_idx=0;
        //             writer.mod[GLOBAL]=new Global;
        //             writer.mod[GLOBAL].sectypes=[global_type];
        //         }
        //         else {
        //             global_idx=cast(uint)(writer.mod[GLOBAL].sectypes.length);
        //             writer.mod[GLOBAL].sectypes~=global_type;
        //         }
        //     }
        //     return global_idx;
        // }
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
        // const uint inject_func_type() {
        //     FuncType func_type=FuncType(Types.FUNC, [Types.I64], null);
        //     uint func_idx;
        //     with(Section) {
        //         if (writer.mod[TYPE] is null) {
        //             func_idx=0;
        //             writer.mod[TYPE]=new Type;
        //             writer.mod[TYPE].sectypes=[func_type];
        //         }
        //         else {
        //             func_idx=cast(uint)(writer.mod[TYPE].sectypes.length);
        //             writer.mod[TYPE].sectypes~=func_type;
        //         }
        //     }
        //     return func_idx;
        // }
        // const func_idx=inject_func_type;

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

//    Wast(wasm_writer, stdout).serialize();



    //auto dasm=Wdisasm(wasm_reader);
    //auto wasm_writer=WasmWriter(wasm_reader);
    // immutable writer_data=wasm_writer.serialize;

    // auto dasm_writer=Wdisasm(writer_data);
//    Wast(wasm_writer, stdout).serialize();
//    auto output=Wast

}
