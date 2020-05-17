module tagion.vm.wasm.WasmWriter;

import std.outbuffer;
import std.bitmanip : nativeToLittleEndian;
import std.traits : isIntegral, isFloatingPoint, EnumMembers, hasMember, Unqual, TemplateArgsOf, PointerTarget, getUDAs, isPointer;
import std.typecons : Tuple;
import std.format;
import std.algorithm.iteration : each, map, sum, fold, filter;
import std.range.primitives : isInputRange;
//import std.traits : Unqual, TemplateArgsOf, PointerTarget, getUDAs;
import std.meta : AliasSeq, staticMap;
import std.exception : assumeUnique;
import std.range : lockstep;

import std.stdio;

import tagion.utils.LEB128 : encode;
import tagion.vm.wasm.WasmBase;
import tagion.vm.wasm.WasmReader;
import tagion.vm.wasm.WasmException;
//import wavm.Wdisasm;

@safe
class WasmWriter {

    alias ReaderModule=WasmReader.Module;

    alias Module=ModuleT!(WasmSection, false);

    alias ModuleIterator=void delegate(const Section sec, ref scope const(Module) mod);

    alias InterfaceModule=InterfaceModuleT!(Module);

    alias ReaderSecType(Section sec)=TemplateArgsOf!(ReaderModule.Types[sec].SecRange)[1];

    Module mod;
    this(ref const(WasmReader) reader) {
        auto loader=new WasmLoader;
        reader(loader);
    }

    static WasmWriter opCall(ref const(WasmReader) reader) {
        return new WasmWriter(reader);
    }

    template AsType(T, TList...) {
        static foreach(E; EnumMembers!Section) {
            static if (is(T == TList[E])) {
                enum AsType=E;
            }
        }
    }

    enum asType(T)=AsType!(T, staticMap!(PointerTarget, Module.Types));

    template FromSecType(SecType, TList...) {
        alias T=WasmSection.SectionT!SecType;
        static foreach(E; EnumMembers!Section) {
            static if (is(T == TList[E]) || (isPointer!(TList[E])) && is(T == PointerTarget!(TList[E]))) {
                enum FromSecType=E;
            }
        }
    }


    enum fromSecType(T)=FromSecType!(T, Module.Types);

    alias getType(Section sec)=WasmSection.Sections[sec];

    class WasmLoader : WasmReader.InterfaceModule {
        alias SecType(Section sec)=Unqual!(PointerTarget!(Unqual!(Module.Types[sec])));
        alias SecElement(Section sec)=TemplateArgsOf!(SecType!sec)[0];
        private Section previous_sec;
        void section_secT(Section sec)(ref scope const(ReaderModule) reader_mod) {
            if (reader_mod[sec] !is null) {
            auto _reader_sec=*reader_mod[sec];
            if (!_reader_sec[].empty) {
                //writefln("%s _reader_sec=%s", sec, _reader_sec.data);
                alias ModT=Module.Types[sec];
                alias ModuleType=SecType!sec; //Unqual!(PointerTarget!(Module.Types[sec]));
                alias SectionElement=TemplateArgsOf!(ModuleType);
                auto _sec=new SecType!sec; //PointerTarget!(Module.Types[sec]);
                mod[sec]=_sec;
                //static if (is(Module[sec] : Section!SecType, SecType)) {
                foreach(s; _reader_sec[]) {
                    _sec.sectypes~=SecElement!(sec)(s); //.name, c.bytes);
                }
            }
            }
        }

        final void custom_sec(ref scope const(ReaderModule) reader_mod) {
            pragma(msg, "Module.Types[Section.CUSTOM] ", Module.Types[Section.CUSTOM]);
            pragma(msg, "Module.Types ", Module.Types);
            check((previous_sec in mod[Section.CUSTOM]) is null,
                format("Custom section after %s has already been definded", previous_sec));
            mod[Section.CUSTOM][previous_sec]=WasmSection.CustomType(*reader_mod[Section.CUSTOM]);
        }

        final void type_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.TYPE;
            section_secT!(Section.TYPE)(reader_mod);
        }

        final void import_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.IMPORT;
            section_secT!(Section.IMPORT)(reader_mod);
        }

        final void function_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.FUNCTION;
            section_secT!(Section.FUNCTION)(reader_mod);
        }

        final void table_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.TABLE;
            section_secT!(Section.TABLE)(reader_mod);
        }

        final void memory_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.MEMORY;
            section_secT!(Section.MEMORY)(reader_mod);
        }

        final void global_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.GLOBAL;
            section_secT!(Section.GLOBAL)(reader_mod);
        }

        final void export_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.EXPORT;
            section_secT!(Section.EXPORT)(reader_mod);
        }

        final void start_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.START;
            mod[Section.START]=new WasmSection.Start(*reader_mod[Section.START]);
        }


        final void element_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.ELEMENT;
            section_secT!(Section.ELEMENT)(reader_mod);
        }

        final void code_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.CODE;
            section_secT!(Section.CODE)(reader_mod);
        }

        final void data_sec(ref scope const(ReaderModule) reader_mod) {
            previous_sec=Section.DATA;
            section_secT!(Section.DATA)(reader_mod);
        }
    }


    immutable(ubyte[]) serialize() const {
        OutBuffer[EnumMembers!Section.length] buffers;
        scope(exit) {
            buffers=null;
        }
        size_t output_size;
        Section previous_sec;
        foreach(E; EnumMembers!Section) {
            if (mod[E] !is null) {
                buffers[E]=new OutBuffer;
                static if (E !is Section.CUSTOM) {
                    mod[E].serialize(buffers[E]);//tmp_bout); //buffers[E]);
                    output_size+=buffers[E].offset+uint.sizeof+Section.sizeof;
                }
                if (E in mod[Section.CUSTOM]) {
                    mod[E][Section.CUSTOM].serialize(buffers[E]);
                }
            }
            previous_sec=E;
        }
        auto output=new OutBuffer;
        output_size+=magic.length+wasm_version.length;
        output.reserve(output_size);
        output.write(magic);
        output.write(wasm_version);
        foreach(sec, b; buffers) {
            if (b !is null) {
                output.write(cast(ubyte)sec);
                output.write(encode(b.offset));
                output.write(b);
//                writefln("output[%s]=%s", sec, output.toBytes);
            }
        }
        // scope output_result=new OutBuffer;
        // output_result.reserve(output_size+magic.length+wasm_version.length+uint.sizeof);
        // output_result.write(magic);
        // output_result.write(wasm_version);
        // output_result.write(encode(output.offset));
        // output_result.write(output.offset);
//        writefln("result=%s", output.toBytes);
        return output.toBytes.idup;
    }

    version(none)
    @trusted
    void opCall(T)(T reader) if (is(T==ModuleIterator) || is(T:InterfaceModule)) {
        //scope Module mod;
        Section previous_sec;
//        writefln("WasmWriter opCall");
        foreach(a; reader[]) {
//            writefln("a=%s", a);
            with(Section) {
                check((a.section !is CUSTOM) && (previous_sec < a.section), "Bad order");
                previous_sec=a.section;
                final switch(a.section) {
                    foreach(E; EnumMembers!(Section)) {
                    case E:
                        const sec=a.sec!E;
                        mod[E]=&sec;
                        static if (is(T==ModuleIterator)) {
                                iter(a.section, mod);
                        }
                        else {
                            enum code=format(q{reader.%s(mod);}, secname(E));
                            mixin(code);
                        }
                        break;
                    }
                }
            }
        }
    }

    struct WasmSection {
        mixin template Serialize() {
            void serialize(ref OutBuffer bout) const {
                alias MainType=typeof(this);
                static if (hasMember!(MainType,  "guess_size")) {
                    bout.reserve(guess_size);
                }

                foreach(i, m; this.tupleof) {
                    alias T=typeof(m);
                    static if (is(T==struct) || is(T==class)) {
                        m.serialize(bout);
                    }
                    else {
                        static if (T.sizeof == 1) {
                            bout.write(cast(ubyte)m);
                        }
                        else static if (isIntegral!T) {
                            bout.write(encode(m));
                        }
                        else static if (isFloatingPoint!T) {
                            bout.write(nativeToLittleEndian(m));
                        }
                        else static if (is(T: U[], U)) {
                            alias spec=getUDAs!(this.tupleof[i], Section);
                            static if ((spec.length == 0) || (spec[0] !is Section.CODE)) {
                                // Check to avoid addinh the length for an expression
                                bout.write(encode(m.length));
                            }
                            static if (U.sizeof == 1) {
                                bout.write(cast(const(ubyte[]))m);
                            }
                            else static if (isIntegral!U) {
                                m.each!((e) => bout.write(encode(e)));
                            }
                            else static if (hasMember!(U,  "serialize")) {
                                //writefln("serialize %s m.length=%d", m, m.length);
                                foreach(e; m) {
                                    e.serialize(bout);
                                }
                                //writefln("bout=%s", bout.toBytes);
                            }
                            else {
                                static assert(0, format("Array type %s is not supported", T.stringof));
                            }
                        }
                        else {
                            static assert(0, format("Type %s is not supported", T.stringof));
                        }
                    }
                }
            }
        }

        struct Limit {
            Limits lim;
            uint from;
            uint to;
            this(ref const(WasmReader.Limit) l) {
                lim=l.lim;
                from=l.from;
                to=l.to;
            }
            void serialize(ref OutBuffer bout) const {
                bout.write(cast(ubyte)lim);
                bout.write(encode(from));
                with(Limits) {
                    final switch(lim) {
                    case INFINITE:
                        // Empty
                        break;
                    case RANGE:
                        bout.write(encode(to));
                        break;
                    }
                }
            }
            //mixin Serialize;
        }

        struct SectionT(SecType) {
            SecType[] sectypes;
            @property size_t length() const pure nothrow {
                return sectypes.length;
            }
            size_t guess_size() const pure nothrow {
                if (sectypes.length>0) {
                    static if (hasMember!(SecType, "guess_size")) {
                        return sectypes.map!(s => s.guess_size()).sum+uint.sizeof;
                    }
                    else {
                        return sectypes.length*SecType.sizeof+uint.sizeof;
                    }
                }
                return 0;
            }
            mixin Serialize;
        }

     alias Sections=AliasSeq!(
         Custom[Section],
         Type,
         Import,
         Function,
         Table,
         Memory,
         Global,
         Export,
         Start,
         Element,
         Code,
         Data);



//        TemplateArgsOf!(ReaderModule.Types[sec])[0];
        // template ReaderModuleSecType(Section sec) {
        //     static if (is(TemplateArgOf!(ReaderModule[sec]) : WasmReader.WasmRange.WasmSection.SectionT!(SecType), SecType)) {
        //         alias ReaderModuleType=SecType;
        //     }
        //     else {
        //         static assert(0, format("The type %s does not have a SecType", ReaderModule[sec].stringof));
        //     }
        // }

        struct CustomType {
            string name;
            immutable(ubyte)[] bytes;
            size_t guess_size() const pure nothrow {
                return name.length+bytes.length+uint.sizeof*2;
            }
            alias ReaderCustomType=Unqual!(PointerTarget!(ReaderModule.Types[Section.CUSTOM]));

            this(ReaderCustomType s) {
                name=s.name;
                bytes=s.bytes;
            }
            mixin Serialize;
        }


        alias Custom=CustomType[Section]; //SectionT!(CustomType);

        struct FuncType {
            Types type;
            immutable(Types)[] params;
            immutable(Types)[] results;
            size_t guess_size() const pure nothrow {
                return params.length+results.length+uint.sizeof*2+Types.sizeof;
            }
            this(const Types type, immutable(Types)[] params, immutable(Types)[] results) {
                this.type=type;
                this.params=params;
                this.results=results;
                writefln("FuncType %s", this);
            }
            this(ref const(ReaderSecType!(Section.TYPE)) s) {
                type=s.type;
                params=s.params;
                results=s.results;
                writefln("ReaderSecType.FuncType %s", this);
            }
            mixin Serialize;
        }

        alias Type=SectionT!(FuncType);

        struct ImportType {
            string mod;
            string name;
            ImportDesc importdesc;
            alias ReaderImportType=ReaderSecType!(Section.IMPORT);
            alias ReaderImportDesc=ReaderImportType.ImportDesc;
            size_t guess_size() const pure nothrow {
                return mod.length+name.length+uint.sizeof*2+ImportDesc.sizeof;
            }
            mixin Serialize;
            struct ImportDesc {
                struct FuncDesc {
                    uint typeidx;
                    this(const(ReaderImportDesc.FuncDesc) f) {
                        typeidx=f.typeidx;
                    }
                    mixin Serialize;
                }
                struct TableDesc {
                    Types type;
                    Limit limit;
                    this(const(ReaderImportDesc.TableDesc) t) {
                        type=t.type;
                        limit=t.limit;
                    }
                    mixin Serialize;
                }
                struct MemoryDesc {
                    Limit limit;
                    this(const(ReaderImportDesc.MemoryDesc) m) {
                        limit=m.limit;
                    }
                    mixin Serialize;
                }
                struct GlobalDesc {
                    Types   type;
                    Mutable mut;
                    this(const Types type, const Mutable mut=Mutable.CONST) {
                        this.type=type;
                        this.mut=mut;
                    }
                    this(const(ReaderImportDesc.GlobalDesc) g) {
                        mut=g.mut;
                        type=g.type;
                    }
                    mixin Serialize;
                }
                protected union {
                    @(IndexType.FUNC)  FuncDesc _funcdesc;
                    @(IndexType.TABLE) TableDesc _tabledesc;
                    @(IndexType.MEMORY) MemoryDesc _memorydesc;
                    @(IndexType.GLOBAL) GlobalDesc _globaldesc;
                }

                protected IndexType _desc;
                mixin Serialize;

                auto get(IndexType IType)() const pure
                    in {
                        assert(_desc is IType);
                    }
                do {
                    foreach(E; EnumMembers!IndexType) {
                        static if (E is IType) {
                            enum code=format("return _%sdesc;", toLower(E.to!string));
                            mixin(code);
                        }
                    }
                }

                @property IndexType desc() const pure nothrow {
                    return _desc;
                }

                this(T)(ref const(T) desc) {
                    static if (is(T:const(FuncDesc))) {
                        _desc=FUNC;
                        _funcdesc=desc;
                    }
                    else static if (is(T:const(TypeDesc))) {
                        _desc=TABLE;
                        _typedesc=desc;
                    }
                    else static if (is(T:const(TableDesc))) {
                        _desc=MEMORY;
                        _tabledesc=desc;
                    }
                    else static if (is(T:const(GlobalDesc))) {
                        _desc=GLOBAL;
                        _globaldesc=desc;
                    }
                    else {
                        static assert(0, format("Type %s is not supported", T.stringof));
                    }
                }

                this(ref const(ReaderImportDesc) importdesc) {
                    with(IndexType) {
                        final switch(importdesc.desc) {
                        case FUNC:
                            _funcdesc=FuncDesc(importdesc.get!(FUNC));
                            break;
                        case TABLE:
                            _tabledesc=TableDesc(importdesc.get!(TABLE));
                            break;
                        case MEMORY:
                            _memorydesc=MemoryDesc(importdesc.get!(MEMORY));
                            break;
                        case GLOBAL:
                            _globaldesc=GlobalDesc(importdesc.get!(GLOBAL));
                            break;
                        }
                    }
                }
            }


            this(T)(string mod, string name, T desc) pure {
                this.mod=mod;
                this.name=name;
                this.importdesc=ImportDesc(desc);
                // static if (is(T:const(FuncDesc))) {
                //     _desc=FUNC;
                //     _funcdesc=desc;
                // }
                // else static if (is(T:const(TypeDesc))) {
                //     _desc=TABLE;
                //     _typedesc=desc;
                // }
                // else static if (is(T:const(TableDesc))) {
                //     _desc=MEMORY;
                //     _tabledesc=desc;
                // }
                // else static if (is(T:const(GlobalDesc))) {
                //     _desc=GLOBAL;
                //     _globaldesc=desc;
                // }
                // else {
                //     static assert(0, format("Type %s is not supported", T.stringof));
                // }
            }

            this(ref const(ReaderImportType) s) {
                auto x=s.mod;
//                writefln("this.mod=%s", this.mod);
                this.mod=s.mod;
                this.name=s.name;
                this.importdesc=ImportDesc(s.importdesc);
                // with(IndexType) {
                //     final switch(s.importdesc.desc) {
                //     case FUNC:
                //         _funcdesc=FuncDesc(s.importdesc.get!(FUNC));
                //         break;
                //     case TABLE:
                //         _tabledesc=TableDesc(s.importdesc.get!(FUNC));
                //         break;
                //     case MEMORY:
                //         _memorydesc=TableDesc(s.importdesc.get!(MEMORY));
                //         break;
                //     case GLOBAL:
                //         _memorydesc=GlobalDesc(s.importdesc.get!(GLOBAL));
                //         break;
                //     }
                // }
            }

        }

        alias Import=SectionT!(ImportType);

        struct Index {
            uint idx;
            this(const uint idx) {
                this.idx=idx;
            }
            this(ref const(ReaderSecType!(Section.FUNCTION)) f) {
                idx=f.idx;
            }
            mixin Serialize;
        }

        alias Function=SectionT!(Index);

        struct TableType {
            Types type;
            Limit limit;
            this(ref const(ReaderSecType!(Section.TABLE)) t) {
                type=t.type;
                limit=Limit(t.limit);
            }
            mixin Serialize;
        }

        alias Table=SectionT!(TableType);

        struct MemoryType {
            Limit limit;
            this(ref const(ReaderSecType!(Section.MEMORY)) m) {
                limit=Limit(m.limit);
                //writefln("MemoryType %s", this);
            }
            mixin Serialize;
        }

        alias Memory=SectionT!(MemoryType);

        struct GlobalType {
            alias GlobalDesc=ImportType.ImportDesc.GlobalDesc;
            GlobalDesc global;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            this(const GlobalDesc global, immutable(ubyte)[] expr) {
                this.global=global;
                this.expr=expr;
                //writefln("GlobalDesc length=%d expr=%s", expr.length, expr);
            }
            this(ref const(ReaderSecType!(Section.GLOBAL)) g) {
                global=ImportType.ImportDesc.GlobalDesc(g.global);
                expr=g.expr;
                //writefln("GlobalDesc length=%d expr=%s", expr.length, expr);
            }
            mixin Serialize;
        }

        alias Global=SectionT!(GlobalType);

        struct ExportType {
            string name;
            IndexType desc;
            uint idx;
            size_t guess_size() const pure nothrow {
                return name.length+uint.sizeof+ImportType.ImportDesc.sizeof;
            }
            this(string name, const uint idx, const IndexType desc=IndexType.FUNC) {
                this.name=name;
                this.desc=desc;
                this.idx=idx;
            }
            this(ref const(ReaderSecType!(Section.EXPORT)) e) {
                name=e.name;
                desc=IndexType(e.desc);
                idx=e.idx;
            }
            // void serialize(ref OutBuffer bout) const {
            //     bout.write(encode(name.length));
            //     bout.write(name);
            //     bout.write(cast(ubyte)desc);
            //     bout.write(encode(idx));
            // }
            mixin Serialize;
        }

        alias Export=SectionT!(ExportType);

        struct Start {
            uint idx;
            alias ReaderStartType=Unqual!(PointerTarget!(ReaderModule.Types[Section.START]));
            this(ref const(ReaderStartType) s) {
                idx=s.idx;
            }
            mixin Serialize;
        }

        struct ElementType {
            uint    tableidx;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            immutable(uint)[]  funcs;
            this(ref const(ReaderSecType!(Section.ELEMENT)) e) {
                tableidx=e.tableidx;
                expr=e.expr;
                funcs=e.funcs;
            }
            mixin Serialize;
        }

        alias Element=SectionT!(ElementType);

        struct CodeType {
            Local[] locals;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            size_t guess_size() const pure nothrow {
                return locals.length*Local.sizeof+expr.length+2*uint.sizeof;
            }
            struct Local {
                uint count;
                Types type;
                mixin Serialize;
            }
            this(Local[] locals, immutable(ubyte[]) expr) {
                this.locals=locals;
                this.expr=expr;
            }
            @trusted
            this(ref const(ReaderSecType!(Section.CODE)) c) {
                locals=new Local[c.locals.length];
                foreach(ref l, reader_l; lockstep(locals, c.locals)) {
                    l.count=reader_l.count;
                    l.type=reader_l.type;
                }
                expr=c[].data;
            }
            ExprRange opSlice() const {
                return ExprRange(expr);
            }
            void serialize(ref OutBuffer bout) const {
                auto tmp_out=new OutBuffer;
                tmp_out.reserve(guess_size);
                tmp_out.write(encode(locals.length));
                locals.each!((l) => l.serialize(tmp_out));//.write(encode(e)));
                tmp_out.write(expr);
                bout.write(encode(tmp_out.offset));
                bout.write(tmp_out.toBytes);
            }
            // mixin Serialize;
        }

        alias Code=SectionT!(CodeType);

        struct DataType {
            uint idx;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            string  base; // init value
            this(ref const(ReaderSecType!(Section.DATA)) d) {
                idx=d.idx;
                expr=d.expr;
                base=d.base;
            }
            mixin Serialize;
        }

        alias Data=SectionT!(DataType);
    }
}

version(none)
unittest {
    import std.stdio;
    import std.file;
    import std.exception : assumeUnique;
    import tagion.vm.wavm.Wast;
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

    writefln("wasm_reader.serialize=%s", wasm_reader.serialize);
    auto wasm_writer=WasmWriter(wasm_reader);

    writeln("wasm_writer.serialize");
    writefln("wasm_writer.serialize=%s", wasm_writer.serialize);
    assert(wasm_reader.serialize == wasm_writer.serialize);
    //auto dasm=Wdisasm(wasm_reader);
    //auto wasm_writer=WasmWriter(wasm_reader);
    // immutable writer_data=wasm_writer.serialize;

    // auto dasm_writer=Wdisasm(writer_data);
//    Wast(wasm_writer, stdout).serialize();
//    auto output=Wast

}
/+
[0, 97, 115, 109, 1, 0, 0, 0, 1, 30, 7, 96, 0, 0, 96, 1, 127, 0, 96, 1, 125, 0, 96, 0, 1, 127, 96, 0, 1, 125, 96, 1, 127, 1, 127, 96, 1, 126, 1, 126, 3, 8, 7, 0, 1, 2, 3, 4, 5, 6, 4, 4, 1, 112, 0, 10, 5, 3, 1, 0,
2, 6, 14, 2, 127, 0, 65, 55, 11, 125, 0, 67, 0, 0, 48, 66, 11, 7, 142, 1, 11, 4, 102, 117, 110, 99, 0, 0, 8, 102, 117, 110, 99, 45, 105, 51, 50, 0, 1, 8, 102, 117, 110, 99, 45, 102, 51, 50, 0, 2, 9, 102, 117, 110, 99, 45, 62, 105, 51, 50, 0, 3, 9, 102, 117, 110, 99, 45, 62, 102, 51, 50, 0, 4, 13, 102, 117, 110, 99, 45, 105, 51, 50, 45, 62, 105, 51, 50, 0, 5, 13, 102, 117, 110, 99, 45, 105, 54, 52, 45, 62, 105, 54, 52, 0, 6, 10, 103, 108, 111, 98, 97, 108, 45, 105, 51, 50, 3, 0, 10, 103, 108, 111, 98, 97, 108, 45, 102, 51, 50, 3, 1, 12, 116, 97, 98, 108, 101, 45, 49, 48, 45, 105, 110, 102, 1, 0, 12, 109, 101, 109, 111, 114, 121, 45, 50, 45, 105, 110, 102, 2, 0, 10, 33, 7, 2, 0, 11, 2, 0, 11, 2, 0, 11, 4, 0, 65, 22, 11, 7, 0, 67, 0, 0, 48, 65, 11, 4, 0, 32, 0, 11, 4, 0, 32, 0, 11]

[0, 97, 115, 109, 1, 0, 0, 0, 1, 30, 7, 96, 0, 0, 96, 1, 127, 0, 96, 1, 125, 0, 96, 0, 1, 127, 96, 0, 1, 125, 96, 1, 127, 1, 127, 96, 1, 126, 1, 126, 3, 8, 7, 0, 1, 2, 3, 4, 5, 6, 4, 4, 1, 112, 0, 10, 5, 3, 1, 0,
2, 6, 5, 2, 0, 127, 0, 125, 7, 142, 1, 11, 4, 102, 117, 110, 99, 0, 0, 8, 102, 117, 110, 99, 45, 105, 51, 50, 0, 1, 8, 102, 117, 110, 99, 45, 102, 51, 50, 0, 2, 9, 102, 117, 110, 99, 45, 62, 105, 51, 50, 0, 3, 9, 102, 117, 110, 99, 45, 62, 102, 51, 50, 0, 4, 13, 102, 117, 110, 99, 45, 105, 51, 50, 45, 62, 105, 51, 50, 0, 5, 13, 102, 117, 110, 99, 45, 105, 54, 52, 45, 62, 105, 54, 52, 0, 6, 10, 103, 108, 111, 98, 97, 108, 45, 105, 51, 50, 3, 0, 10, 103, 108, 111, 98, 97, 108, 45, 102, 51, 50, 3, 1, 12, 116, 97, 98, 108, 101, 45, 49, 48, 45, 105, 110, 102, 1, 0, 12, 109, 101, 109, 111, 114, 121, 45, 50, 45, 105, 110, 102, 2, 0, 10, 26, 7, 0, 11, 0, 11, 0, 11, 0, 65, 22, 11, 0, 67, 0, 0, 48, 65, 11, 0, 32, 0, 11, 0, 32, 0, 11]
+/
