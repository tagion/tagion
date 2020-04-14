module wavm.WasmWriter;

import std.outbuffer;
import std.bitmanip : nativeToLittleEndian;
import std.traits : isIntegral, isFloatingPoint, EnumMembers, hasMember;
import std.typecons : Tuple;
import std.format;
import std.algorithm.iteration : each, map, sum, fold, filter;
import std.range.primitives : isInputRange;
import std.traits : Unqual;
import std.exception : assumeUnique;

import wavm.LEB128 : encode;
import wavm.WasmBase;
import wavm.WasmReader;
import wavm.Wdisasm;

@safe
class WasmWriter {
    //alias Types=WasmReader.Types;
    //alias Section=WasmReader.Section;
    //alias secname=Wdisasm.secname;
    //alias Limits=WasmReader.Limits;
    //alias Mutable=WasmReader.Mutable;
    //alias IndexType=WasmReader.IndexType;


    const(WasmReader) reader;
    this(ref const(WasmReader) reader) {
        this.reader=reader;
    }

    alias Module=ModuleT!(WasmSection);
    // alias Module=Tuple!(
    //     const(WasmSection.Custom)*,   secname(Section.CUSTOM),
    //     const(WasmSection.Type)*,     secname(Section.TYPE),
    //     const(WasmSection.Import)*,   secname(Section.IMPORT),
    //     const(WasmSection.Function)*, secname(Section.FUNCTION),
    //     const(WasmSection.Table)*,    secname(Section.TABLE),
    //     const(WasmSection.Memory)*,   secname(Section.MEMORY),
    //     const(WasmSection.Global)*,   secname(Section.GLOBAL),
    //     const(WasmSection.Export)*,   secname(Section.EXPORT),
    //     const(WasmSection.Start)*,    secname(Section.START),
    //     const(WasmSection.Element)*,  secname(Section.ELEMENT),
    //     const(WasmSection.Code)*,     secname(Section.CODE),
    //     const(WasmSection.Data)*,     secname(Section.DATA),
    //     );

    immutable(ubyte[]) serialize(ref const(Module) mod) const {
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

    version(none) {
    @trusted
    void opCall(T)(T iter) if (is(T==WasmReader.ModuleIterator) || is(T:WasmReader.InterfaceModule)) {
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
                            mod[E]=&sec;
                            static if (is(T==ModuleIterator)) {
                                iter(a.section, mod);
                            }
                            else {
                                enum code=format(q{iter.%s(mod);}, secname(E));
                                mixin(code);
                            }
                            break;
                        }
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
            mixin Serialize;
        }

        struct SectionT(SecType) {
            SecType[] secs;
            @property size_t length() const pure nothrow {
                return secs.length;
            }
            size_t guess_size() const pure nothrow {
                if (secs.length>0) {
                    static if (hasMember!(SecType, "guess_size")) {
                        pragma(msg, typeof(secs.map!(s => s.guess_size())));
                        pragma(msg, typeof(secs.map!(s => s.guess_size()).sum));
                        return secs.map!(s => s.guess_size()).sum+uint.sizeof;
                    }
                    else {
                        return secs.length*SecType.sizeof+uint.sizeof;
                    }
                }
                return 0;
            }
            mixin Serialize;
        }

        struct CustomType {
            string name;
            immutable(ubyte)[] bytes;
            size_t guess_size() const pure nothrow {
                return name.length+bytes.length+uint.sizeof*2;
            }
            mixin Serialize;
        }

        alias Custom=SectionT!(CustomType);

        struct FuncType {
            Types type;
            Types[] params;
            Types[] results;
            size_t guess_size() const pure nothrow {
                return params.length+results.length+uint.sizeof*2+Types.sizeof;
            }
            mixin Serialize;
        }

        alias Type=SectionT!(FuncType);

        struct ImportType {
            string mod;
            string name;
            ImportDesc importdesc;
            size_t guess_size() const pure nothrow {
                return mod.length+name.length+uint.sizeof*2+ImportDesc.sizeof;
            }
            mixin Serialize;
            struct ImportDesc {
                struct FuncDesc {
                    uint typeidx;
                    mixin Serialize;
                }
                struct TableDesc {
                    Types type;
                    Limit limit;
                    mixin Serialize;
                }
                struct MemoryDesc {
                    Limit limit;
                    mixin Serialize;
                }
                struct GlobalDesc {
                    Mutable mut;
                    Types   type;
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

                this(T)(string mod, string name, T desc) pure {
                    this.mod=mod;
                    this.name=name;
                    // static if (is(T:const(FuncDesc))) {
                    //     _desc=FUNC;
                    // }
                    // else static if (is(T:const(FuncDesc))) {
                    //     _desc=TABLE;
                    // }
                    // else static if (is(T:const(FuncDesc))) {
                    //     _desc=MEMORY;
                    // }
                    // else static if (is(T:const(FuncDesc))) {
                    // }
                    // else {
                    //     static assert(0, format("Type %s is not supported", T.stringof));
                    // }

                }
            }
        }

        alias Import=SectionT!(ImportType);

        struct Index {
            uint idx;
            mixin Serialize;
        }

        alias Function=SectionT!(Index);

        struct TableType {
            Types type;
            Limit limit;
            mixin Serialize;
        }

        alias Table=SectionT!(TableType);

        struct MemoryType {
            Limit limit;
            mixin Serialize;
        }

        alias Memory=SectionT!(MemoryType);

        struct GlobalType {
            ImportType.ImportDesc.GlobalDesc global;
            immutable(ubyte)[] expr;
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
            mixin Serialize;
        }

        alias Export=SectionT!(ExportType);

        struct Start {
            uint idx;
            mixin Serialize;
        }

        struct ElementType {
            uint    tableidx;
            const(ubyte)[] expr;
            const(uint)[]  funcs;
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
            mixin Serialize;
        }

        alias Code=SectionT!(CodeType);

        struct DataType {
            uint idx;
            immutable(ubyte)[] expr;
            string  base; // init value
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
    immutable code=fread(filename);
    auto wasm_reader=WasmReader(code);
    //auto dasm=Wdisasm(wasm);
    //auto wasm_writer=WasmWriter(wasm_reader);
    //Wast(dasm, stdout).serialize();
//    auto output=Wast

}
