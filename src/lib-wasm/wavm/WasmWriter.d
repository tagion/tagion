module wavm.WasmWriter;

import std.outbuffer;
import std.bitmanip : nativeToLittleEndian;
import std.traits : isIntegral, isFloatingPoint, EnumMembers, hasMember;
import std.typecons : Tuple;
import std.format;
import std.algorithm.iteration : each, map, sum, fold, filter;
import std.range.primitives : isInputRange;
import std.traits : Unqual, TemplateArgsOf, PointerTarget;
import std.exception : assumeUnique;
import std.range : lockstep;

import std.stdio;

import wavm.LEB128 : encode;
import wavm.WasmBase;
import wavm.WasmReader;
import wavm.Wdisasm;

@safe
class WasmWriter {

    alias ReaderModule=WasmReader.Module;

    alias Module=ModuleT!(WasmSection);

    alias ModuleIterator=void delegate(const Section sec, ref scope const(Module) mod);

    alias InterfaceModule=InterfaceModuleT!(Module);

    alias ReaderSecType(Section sec)=TemplateArgsOf!(ReaderModule.Types[sec].SecRange)[1];

    Module mod;
//    const(WasmReader) reader;
    // this(ref const(WasmReader) reader) pure {
    //     this.reader=reader;
    // }

    pragma(msg, "WasmLoader.custom_sec=", typeof(WasmLoader.custom_sec));
    pragma(msg, "WasmReader.InterfaceModule=", WasmReader.InterfaceModule);
    class WasmLoader : WasmReader.InterfaceModule {

        alias SecType(Section sec)=Unqual!(PointerTarget!(Unqual!(Module.Types[sec])));
        alias SecElement(Section sec)=TemplateArgsOf!(SecType!sec)[0];
        void section_secT(Section sec)(ref scope const(ReaderModule) reader_mod) {
            auto _reader_sec=*reader_mod[sec];
            if (!_reader_sec[].empty) {
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

        final void custom_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.CUSTOM)(reader_mod);
        }

        final void type_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.TYPE)(reader_mod);
        }

        final void import_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.IMPORT)(reader_mod);
        }

        final void function_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.FUNCTION)(reader_mod);
        }

        final void table_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.TABLE)(reader_mod);
        }

        final void memory_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.TABLE)(reader_mod);
        }

        final void global_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.GLOBAL)(reader_mod);
        }

        final void export_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.EXPORT)(reader_mod);
        }

        final void start_sec(ref scope const(ReaderModule) reader_mod) {
            pragma(msg, "*reader_mod[Section.START]", typeof(*(reader_mod[Section.START])));
            pragma(msg, "mod[Section.START]=", typeof(mod[Section.START]));
            pragma(msg, "Start=", WasmSection.Start);
            mod[Section.START]=new WasmSection.Start(*reader_mod[Section.START]);
//            xmod[Section.START.start_sec=Module[Section.START](*mod.start_sec);
        }


        final void element_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.ELEMENT)(reader_mod);
        }

        final void code_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.CODE)(reader_mod);
        }

        final void data_sec(ref scope const(ReaderModule) reader_mod) {
            section_secT!(Section.DATA)(reader_mod);
        }

// //        alias custom_sec=section_secT!(Section.CUSTOM);
//         alias type_sec=section_secT!(Section.TYPE);
//         alias import_sec=section_secT!(Section.IMPORT);
//         alias function_sec=section_secT!(Section.FUNCTION);
//         alias table_sec=section_secT!(Section.TABLE);
//         alias memory_sec=section_secT!(Section.MEMORY);
//         alias global_sec=section_secT!(Section.GLOBAL);
//         alias export_sec=section_secT!(Section.EXPORT);

//         void start_sec(ref scope const(ReaderModule) mod) {
// //            xmod[Section.START.start_sec=Module[Section.START](*mod.start_sec);
//         }

//         alias code_sec=section_secT!(Section.CODE);
//         alias data_sec=section_secT!(Section.DATA);

    }

    // static WasmWriter opCall(ref const(WasmReader) reader) pure {
    //     return new WasmWriter(reader);
    // }

    immutable(ubyte[]) serialize() const {
        OutBuffer[EnumMembers!Section.length] buffers;
        scope(exit) {
            buffers=null;
        }
        size_t output_size;
        foreach(E; EnumMembers!Section) {
            if (mod[E] !is null) {
                mod[E].serialize(buffers[E]);
                output_size+=buffers[E].offset+uint.sizeof+Section.sizeof;
            }
        }
        auto output=new OutBuffer;
        output.reserve(output_size);
        foreach(sec, b; buffers) {
            if (b !is null) {
                output.write(sec);
                output.write(encode(b.offset));
                output.write(b);
            }
        }
        auto output_result=new OutBuffer;
        output_result.reserve(output_size+magic.length+wasm_version.length+uint.sizeof);
        output_result.write(magic);
        output_result.write(wasm_version);
        output_result.write(encode(output.offset));
        output_result.write(output.offset);
        return output_result.toBytes.idup;
    }

    @trusted
    void opCall(T)(T iter) if (is(T==ModuleIterator) || is(T:InterfaceModule)) {
        scope Module mod;
        Section previous_sec;
        foreach(a; reader[]) {
            with(WasmReader.Section) {
                check((a.section !is CUSTOM) && (previous_sec < a.section), "Bad order");
                previous_sec=a.section;
                final switch(a.section) {
                    foreach(E; EnumMembers!(WasmReader.Section)) {
                    case E:
                        const sec=a.sec!E;
                        xmod[E]=&sec;
                        static if (is(T==ModuleIterator)) {
                                iter(a.section, xmod);
                        }
                        else {
                            enum code=format(q{iter.%s(xmod);}, secname(E));
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
                static if (hasMember!(typeof(this),  "guess_size")) {
                    bout.reserve(guess_size);
                }
                foreach(i, m; this.tupleof) {
                    //enum name=basename!(this.tupleof[i]);
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
                            bout.write(encode(m.length));
                            static if (U.sizeof == 1) {
                                bout.write(cast(const(ubyte[]))m);
                            }
                            else static if (isIntegral!U) {
                                m.each!((e) => bout.write(encode(e)));
                            }
                            else static if (hasMember!(U,  "serialize")) {
                                foreach(e; m) {
                                    e.serialize(bout);
                                }
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
            mixin Serialize;
        }

        struct SectionT(SecType) {
            SecType[] sectypes;
            @property size_t length() const pure nothrow {
                return sectypes.length;
            }
            size_t guess_size() const pure nothrow {
                if (sectypes.length>0) {
                    static if (hasMember!(SecType, "guess_size")) {
                        pragma(msg, typeof(sectypes.map!(s => s.guess_size())));
                        pragma(msg, typeof(sectypes.map!(s => s.guess_size()).sum));
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
            //alias ReaderSecType=ReaderModuleSecType!(Section.CUSTOM);
            pragma(msg, ">>ReaderSecType!(Section.CUSTOM)=", ReaderSecType!(Section.CUSTOM));
            this(ReaderSecType!(Section.CUSTOM) s) {
                name=s.name;
            }
            mixin Serialize;
        }

        alias Custom=SectionT!(CustomType);

        struct FuncType {
            Types type;
            immutable(Types)[] params;
            immutable(Types)[] results;
            size_t guess_size() const pure nothrow {
                return params.length+results.length+uint.sizeof*2+Types.sizeof;
            }
            pragma(msg, ">>ReaderSecType!(Section.TYPE)=", ReaderSecType!(Section.TYPE));
            this(ref const(ReaderSecType!(Section.TYPE)) s) {
                type=s.type;
                params=s.params;
                results=s.results;
            }
            mixin Serialize;
        }

        alias Type=SectionT!(FuncType);

        struct ImportType {
            string mod;
            string name;
            ImportDesc importdesc;
            alias ReaderImportType=ReaderSecType!(Section.IMPORT);
            alias ReaderImportDesc1=WasmReader.WasmRange.WasmSection.ImportType.ImportDesc;
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
                    Mutable mut;
                    Types   type;
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

                // void serialize(scope ref OutBuffer bout) const {

                // }
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
                pragma(msg, "ReaderImportType=", ReaderImportType);
                auto x=s.mod;
                writefln("this.mod=%s", this.mod);
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
            }
            mixin Serialize;
        }

        alias Memory=SectionT!(MemoryType);

        struct GlobalType {
            ImportType.ImportDesc.GlobalDesc global;
            immutable(ubyte)[] expr;
            this(ref const(ReaderSecType!(Section.GLOBAL)) g) {
                global=ImportType.ImportDesc.GlobalDesc(g.global);
                expr=expr;
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
            this(ref const(ReaderSecType!(Section.EXPORT)) e) {
                name=e.name;
                desc=IndexType(e.desc);
                idx=e.idx;
            }
            mixin Serialize;
        }

        alias Export=SectionT!(ExportType);

        struct Start {
            uint idx;
//            alias ReaderStartType=WasmReader.Module[Section.START];
            pragma(msg, "START ", Unqual!(PointerTarget!(ReaderModule.Types[Section.START]))); //.Module[Section.START]);
            alias ReaderStartType=Unqual!(PointerTarget!(ReaderModule.Types[Section.START])); //WasmReader.Module[Section.START];

            this(ref const(ReaderStartType) s) {
                idx=s.idx;
            }
            mixin Serialize;
        }

        struct ElementType {
            uint    tableidx;
            immutable(ubyte)[] expr;
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
            immutable(ubyte)[] data;
            struct Local {
                uint count;
                Types type;
                mixin Serialize;
            }
            @trusted
            this(ref const(ReaderSecType!(Section.CODE)) c) {
                locals=new Local[c.locals.length];
                foreach(ref l, reader_l; lockstep(locals, c.locals)) {
                    l.count=reader_l.count;
                    l.type=reader_l.type;
                }
                data=c.data;
            }
            mixin Serialize;
        }

        alias Code=SectionT!(CodeType);

        struct DataType {
            uint idx;
            immutable(ubyte)[] expr;
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
    string filename="../tests/wasm/data_4.wasm";
    immutable read_data=fread(filename);
    auto wasm_reader=WasmReader(read_data);
    //auto dasm=Wdisasm(wasm_reader);
    // auto wasm_writer=WasmWriter(wasm_reader);
    // immutable writer_data=wasm_writer.serialize;

    // auto dasm_writer=Wdisasm(writer_data);
//    Wast(wasm_writer, stdout).serialize();
//    auto output=Wast

}
