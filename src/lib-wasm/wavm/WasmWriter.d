module wavm.WasmWriter;

import std.outbuffer;

import wavm.WasmReader;

@safe
class WasmWriter {
    alias Types=WasmReader.Types;
    alias Section=WasmReader.Section;
    alias secname=WasmReader.secname;
    this(WasmReader reader) {
    }

    alias Module=Tuple!(
        const(WasmSection.Custom)*,   secname(Section.CUSTOM),
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

    immutable(ubyte[]) serialize(ref const(Module) mod) const {
        scope OutBuffer[EnumMembers!Section.length] buffers;
        foreach(E; EnumMember!Section) {
            if (mod[E] !is null) {
                //buffers[E]=new OutBuffer;
                mod[E].serialize(buffers[E]);
            }
        }
        const output_size=buffers.map!(a => a.length+uint.sizeof+E.sizeof).sum;
        scope output=new OutBuffer;
        output.reserve(output_size);
        foreach(sec, b; buffers) {
            if (b !is null) {
                output.write(cast(Section)sec);
                output.write(encode(b.offset));
                output.write(b);
            }
        }
        auto output_result=new OutBuffer;
        output_result.reserve(outsize_size+magic.length+wasm_version+uint.sizeof);
        output_result.write(magic);
        output_result.write(wasm_version);
        output_result.write(encode(output.offset));
        output_result.write(output.offset);
        auto result=output_result.toBytes;
        return assumeUnique(result);
    }

    struct WasmSection {
//        alias u32=encude!uint;
        //    protected OutBuffer output;
        this() {
            output=new OutBuffer;
        }

        struct SectionT(SecType) {
            SecType[] secs;
            alias length=secs.length;
            void serialize(scope ref OutBuffer bout) {
                //bout=new OutBuffer;
                size_t size=secs.map(s => s.name.length+s.bytes.length+2*uint.sizeof).sum+uint.sizeof;
                bout.reserve(size);
                bout.write(encode(secs.length));
                foreach(s; secs) {
                    s.serialize(bout);
                }
            }
        }

        struct CustomType {
            string name;
            immutable(ubyte)[] bytes;
            void serialize(scope ref OutBuffer bout) {
                bout.write(encode(name.length));
                bout.write(name);
                bout.write(encode(bytes.length));
                bout.write(bytes);
            }
        }

        alias Custom=SectionT!(CustomType);

        struct FuncType {
            Types type;
            Types[] params;
            Types[] results;
            void serialize(scope ref OutBuffer bout) {
                bout.write(type);
                bout.write(encode(params.length));
                bout.write(params);
                bout.write(encode(results.length));
                bout.write(results);
            }
        }

        alias Type=SectionT!(FuncType);

        struct ImportType {
            string mod;
            string name;
            ImportDesc importdesc;
            struct ImportDesc {
                struct FuncDesc {
                    uint typeidx;
                }
                struct TableDesc {
                    Types type;
                    Limit limit;
                }
                struct MemoryDesc {
                    Limit limit;
                }
                struct GlobalDesc {
                    Mutable mut;
                    Types   type;
                }
                protected union {
                    @(IndexType.FUNC)  FuncDesc _funcdesc;
                    @(IndexType.TABLE) TableDesc _tabledesc;
                    @(IndexType.MEMORY) MemoryDesc _memorydesc;
                    @(IndexType.GLOBAL) GlobalDesc _globaldesc;
                }

                protected IndexType _desc;

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

//                 this(immutable(ubyte[]) data, ref size_t index) {
//                     _desc=cast(IndexType)data[index];
//                     index+=IndexType.sizeof;
//                     with(IndexType) {
//                         final switch(_desc) {
//                         case FUNC:
// //                        _funcdesc=FuncDesc(data, index);
//                             break;
//                         case TABLE:
// //                        _tabledesc=TableDesc(data, index);
//                             break;
//                         case MEMORY:
// //                        _memorydesc=MemoryDesc(data, index);
//                             break;
//                         case GLOBAL:
// //                        _globaldesc=GlobalDesc(data, index);
//                             break;
//                         }
//                     }
//                 }

            }
        }

        alias Import=SectionT!(ImportType);

        struct Index {
            uint idx;
        }

        alias Function=SectionT!(Index);

        struct TableType {
            Types type;
            Limit limit;
        }

        alias Table=SectionT!(TableType);

        struct MemoryType {
            Limit limit;
        }

        alias Memory=SectionT!(MemoryType);

        struct GlobalType {
            ImportDesc.GlobalDesc global;
            immutable(ubyte)[] expr;
        }

        alias Global=SectionT!(GlobalType);

        struct ExportType {
            string name;
            IndexType desc;
            uint idx;
        }

        alias Export=SectionT!(ExportType);

        struct Start {
            uint idx;
        }

        struct ElementType {
            uint    tableidx;
            const(ubyte)[]  expr;
            const(uint)[]  funcs;
        }

        alias Element=SectionT!(ElementType);

        struct CodeType {
            Local[] locals;
            immutable(ubyte)[] data;
        }

        alias Code=SectionT!(CodeType);

        struct DataType {
            uint idx;
            immutable(ubyte)[] expr;
            string  base; // init value
        }

        alias Data=SectionT!(DataType);


    }
}
