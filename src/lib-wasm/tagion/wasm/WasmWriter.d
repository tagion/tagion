module tagion.wasm.WasmWriter;

import std.outbuffer;
import std.bitmanip : nativeToLittleEndian;
import std.traits : isIntegral, isFloatingPoint, EnumMembers, hasMember, Unqual,
    TemplateArgsOf, PointerTarget, getUDAs, isPointer, ConstOf, ForeachType, FieldNameTuple;
import std.typecons : Tuple;
import std.format;
import std.algorithm;
import std.range.primitives : isInputRange;

import std.meta : staticMap, Replace;
import std.exception : assumeUnique;
import std.range : lockstep;
import std.array : join;

import std.stdio;

import tagion.utils.LEB128 : encode;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmReader;
import tagion.wasm.WasmException;

@safe class WasmWriter {

    alias ReaderSections = WasmReader.Sections;

    alias ReaderCustom = ReaderSections[Section.CUSTOM];

    alias Sections = SectionsT!(WasmSection);

    // The first element Custom is Sections sequency is replaced with CustomList
    alias Modules = Tuple!(Replace!(WasmSection.Custom, WasmSection.CustomList, Sections));
    //    alias InterfaceModule = InterfaceModuleT!(Sections);

    alias ReaderSecType(Section sec) = TemplateArgsOf!(ReaderSections[sec].SecRange)[1];

    Modules mod;
    Sections[Sec] section(Section Sec)() {
        if (!mod[Sec]) {
            mod[Sec] = new Sections[Sec];
        }
        return mod[Sec];
    }

    this(ref const(WasmReader) reader) {
        auto loader = new WasmLoader;
        reader(loader);
    }

    this() pure nothrow @nogc {
        // empty
    }

    static WasmWriter opCall(ref const(WasmReader) reader) {
        return new WasmWriter(reader);
    }

    template AsType(T, TList...) {
        static foreach (E; EnumMembers!Section) {
            static if (is(T == TList[E])) {
                enum AsType = E;
            }
        }
    }

    enum asType(T) = AsType!(T, staticMap!(PointerTarget, Module.Types));

    template FromSecType(SecType, TList...) {
        alias T = WasmSection.SectionT!SecType;
        static foreach (E; EnumMembers!Section) {
            static if (is(T == TList[E])) {
                enum FromSecType = E;
            }
        }
    }

    enum fromSecType(T) = FromSecType!(T, Sections);

    mixin template loadSec(Section sec_type) {
        enum code = format(q{
                final void %s(ref ConstOf!(ReaderSections[Section.%s]) sec) {
                    enum sec_type=Section.%s;
                    previous_sec=sec_type;
                    section_secT!(sec_type)(sec);
                }
            }, secname(sec_type), sec_type, sec_type);
        mixin(code);
    }

    class WasmLoader : WasmReader.InterfaceModule {
        alias SecElement(Section sec) = TemplateArgsOf!(Sections[sec])[0];
        private Section previous_sec;
        void section_secT(Section sec)(ref ConstOf!(ReaderSections[sec]) _reader_sec) {
            if (_reader_sec !is null) {
                alias ModuleType = Sections[sec];
                alias SectionElement = TemplateArgsOf!(ModuleType);
                auto _sec = new ModuleType;
                mod[sec] = _sec;
                foreach (s; _reader_sec[]) {
                    _sec.sectypes ~= SecElement!(sec)(s);
                }
            }
        }

        final void custom_sec(ref ConstOf!(ReaderCustom) sec) {
            mod[Section.CUSTOM].add(previous_sec, sec);
        }

        final void start_sec(ref ConstOf!(ReaderSections[Section.START]) sec) {
            previous_sec = Section.START;
            mod[Section.START] = new WasmSection.Start(sec);
        }

        static foreach (Sec; EnumMembers!Section) {
            static if (Sec !is Section.START && Sec !is Section.CUSTOM) {
                mixin loadSec!Sec;

            }
        }

    }

    immutable(ubyte[]) serialize() const {
        OutBuffer[EnumMembers!Section.length + 1] buffers;
        OutBuffer[EnumMembers!Section.length + 1] custom_buffers;
        scope (exit) {
            buffers = null;
            custom_buffers = null;
        }
        size_t output_size;
        Section previous_sec;
        void output_custom(const(WasmSection.Custom) custom) {
            if (custom) {
                custom_buffers[previous_sec] = new OutBuffer;
                custom_buffers[previous_sec].reserve(custom.guess_size);
                custom.serialize(custom_buffers[previous_sec]);
            }
        }

        foreach (E; EnumMembers!Section) {
            foreach (const sec; mod[Section.CUSTOM].list[previous_sec]) {
                output_custom(sec);
            }
            static if (E !is Section.CUSTOM) {
                if (mod[E]!is null) {
                    buffers[E] = new OutBuffer;
                    static if (E !is Section.CUSTOM) {
                        mod[E].serialize(buffers[E]);
                        output_size += buffers[E].offset + uint.sizeof + Section.sizeof;
                    }
                }
            }
            previous_sec = E;
        }
        foreach (const sec; mod[Section.CUSTOM].list[previous_sec]) {
            output_custom(sec);
        }
        previous_sec = Section.CUSTOM;
        auto output = new OutBuffer;
        output_size += magic.length + wasm_version.length;
        output.reserve(output_size);
        output.write(magic);
        output.write(wasm_version);
        void append_buffer(const OutBuffer b, const(Section) sec) {
            if (b !is null) {
                output.write(cast(ubyte) sec);
                output.write(encode(b.offset));
                output.write(b);
            }
        }

        foreach (E; EnumMembers!Section) {
            append_buffer(buffers[E], E);
            append_buffer(custom_buffers[E], Section.CUSTOM);
        }
        append_buffer(custom_buffers[$ - 1], Section.CUSTOM);
        return output.toBytes.idup;
    }

    struct WasmSection {
        mixin template Serialize() {
            final void serialize(ref OutBuffer bout) const {
                alias MainType = typeof(this);
                static if (hasMember!(MainType, "guess_size")) {
                    bout.reserve(guess_size);
                }
                foreach (i, m; this.tupleof) {
                    alias T = typeof(m);
                    static if (is(T == struct) || is(T == class)) {
                        m.serialize(bout);
                    }
                    else {
                        static if (T.sizeof == 1) {
                            bout.write(cast(ubyte) m);
                        }
                        else static if (isIntegral!T) {
                            bout.write(encode(m));
                        }
                        else static if (isFloatingPoint!T) {
                            bout.write(nativeToLittleEndian(m));
                        }
                        else static if (is(T : U[], U)) {
                            alias spec = getUDAs!(this.tupleof[i], Section);
                            static if ((spec.length == 0) || (spec[0]!is Section.CODE)) {
                                // Check to avoid adding the length for an expression
                                bout.write(encode(m.length));
                            }
                            static if (U.sizeof == 1) {
                                bout.write(cast(const(ubyte[])) m);
                            }
                            else static if (isIntegral!U) {
                                m.each!((e) => bout.write(encode(e)));
                            }
                            else static if (hasMember!(U, "serialize")) {
                                foreach (e; m) {
                                    e.serialize(bout);
                                }
                            }
                            else {
                                static assert(0,
                                        format("Array type %s is not supported", T.stringof));
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
                lim = l.lim;
                from = l.from;
                to = l.to;
            }

            void serialize(ref OutBuffer bout) const {
                bout.write(cast(ubyte) lim);
                bout.write(encode(from));
                with (Limits) {
                    final switch (lim) {
                    case INFINITE:
                        // Empty
                        break;
                    case RANGE:
                        bout.write(encode(to));
                        break;
                    }
                }
            }
        }

        static class SectionT(SecType) {
            SecType[] sectypes;
            @property size_t length() const pure nothrow {
                return sectypes.length;
            }

            size_t guess_size() const pure nothrow {
                if (sectypes.length > 0) {
                    static if (hasMember!(SecType, "guess_size")) {
                        return sectypes.map!(s => s.guess_size()).sum + uint.sizeof;
                    }
                    else {
                        return sectypes.length * SecType.sizeof + uint.sizeof;
                    }
                }
                return 0;
            }

            mixin Serialize;
        }

        static class Custom {
            string name;
            immutable(ubyte)[] bytes;
            size_t guess_size() const pure nothrow {
                return name.length + bytes.length + uint.sizeof * 2;
            }

            this(string name, immutable(ubyte[]) bytes) pure nothrow {
                this.name = name;
                this.bytes = bytes;
            }

            this(_ReaderCustom)(const(_ReaderCustom) s) pure nothrow {
                name = s.name;
                bytes = s.bytes;
            }

            mixin Serialize;
        }

        struct CustomList {
            Custom[][EnumMembers!(Section).length + 1] list;
            void add(_ReaderCustom)(const size_t sec_index, const(_ReaderCustom) s) {
                list[sec_index] ~= new Custom(s);
            }

        }

        struct FuncType {
            Types type;
            immutable(Types)[] params;
            immutable(Types)[] results;
            size_t guess_size() const pure nothrow {
                return params.length + results.length + uint.sizeof * 2 + Types.sizeof;
            }

            this(const Types type, immutable(Types)[] params, immutable(Types)[] results) {
                this.type = type;
                this.params = params;
                this.results = results;
            }

            this(ref const(ReaderSecType!(Section.TYPE)) s) {
                type = s.type;
                params = s.params;
                results = s.results;
            }

            mixin Serialize;
        }

        alias Type = SectionT!(FuncType);

        struct ImportType {
            string mod;
            string name;
            ImportDesc importdesc;
            alias ReaderImportType = ReaderSecType!(Section.IMPORT);
            alias ReaderImportDesc = ReaderImportType.ImportDesc;
            size_t guess_size() const pure nothrow {
                return mod.length + name.length + uint.sizeof * 2 + ImportDesc.sizeof;
            }

            mixin Serialize;
            struct ImportDesc {
                struct FuncDesc {
                    uint funcidx;
                    this(const(ReaderImportDesc.FuncDesc) f) {
                        funcidx = f.funcidx;
                    }

                    mixin Serialize;
                }

                struct TableDesc {
                    Types type;
                    Limit limit;
                    this(const(ReaderImportDesc.TableDesc) t) {
                        type = t.type;
                        limit = t.limit;
                    }

                    mixin Serialize;
                }

                struct MemoryDesc {
                    Limit limit;
                    this(const(ReaderImportDesc.MemoryDesc) m) {
                        limit = m.limit;
                    }

                    mixin Serialize;
                }

                struct GlobalDesc {
                    Types type;
                    Mutable mut;
                    this(const Types type, const Mutable mut = Mutable.CONST) {
                        this.type = type;
                        this.mut = mut;
                    }

                    this(const(ReaderImportDesc.GlobalDesc) g) {
                        mut = g.mut;
                        type = g.type;
                    }

                    mixin Serialize;
                }

                protected union {
                    @(IndexType.FUNC) FuncDesc _funcdesc;
                    @(IndexType.TABLE) TableDesc _tabledesc;
                    @(IndexType.MEMORY) MemoryDesc _memorydesc;
                    @(IndexType.GLOBAL) GlobalDesc _globaldesc;
                }

                protected IndexType _desc;
                void serialize(ref OutBuffer bout) const {
                    with (IndexType)
                        bout.write(cast(ubyte) _desc);
                    final switch (_desc) {
                        foreach (E; EnumMembers!IndexType) {
                    case E:
                            get!E.serialize(bout);
                            break;
                        }
                    }
                }

                auto get(IndexType IType)() const pure
                in {
                    assert(_desc is IType);
                }
                do {
                    //static foreach (m; __traits(allMembers, ImportDesc)) {
                    static foreach (m; FieldNameTuple!ImportDesc) {
                        {
                            enum get_indextype_code = format(q{enum get_indextype=getUDAs!(%s, IndexType);},
                                        m);
                            mixin(get_indextype_code);
                            static if (get_indextype.length is 1) {
                                static if (IType is get_indextype[0]) {
                                    enum return_code = format(q{auto result=%s;}, m);
                                    mixin(return_code);
                                    return result;
                                }
                            }
                        }
                    }
                }

                @property IndexType desc() const pure nothrow {
                    return _desc;
                }

                this(T)(ref const(T) desc) {
                    with (IndexType) {
                        static if (is(T : const(FuncDesc))) {
                            _desc = FUNC;
                            _funcdesc = desc;
                        }
                        else static if (is(T : const(TableDesc))) {
                            _desc = TABLE;
                            _tabledesc = desc;
                        }
                        else static if (is(T : const(MemoryDesc))) {
                            _desc = MEMORY;
                            _memorydesc = desc;
                        }
                        else static if (is(T : const(GlobalDesc))) {
                            _desc = GLOBAL;
                            _globaldesc = desc;
                        }
                        else {
                            static assert(0, format("Type %s is not supported", T.stringof));
                        }
                    }
                }

                this(ref const(ReaderImportDesc) importdesc) {
                    with (IndexType) {
                        final switch (importdesc.desc) {
                        case FUNC:
                            _funcdesc = FuncDesc(importdesc.get!(FUNC));
                            break;
                        case TABLE:
                            _tabledesc = TableDesc(importdesc.get!(TABLE));
                            break;
                        case MEMORY:
                            _memorydesc = MemoryDesc(importdesc.get!(MEMORY));
                            break;
                        case GLOBAL:
                            _globaldesc = GlobalDesc(importdesc.get!(GLOBAL));
                            break;
                        }
                    }
                }
            }

            this(T)(string mod, string name, T desc) pure {
                this.mod = mod;
                this.name = name;
                this.importdesc = ImportDesc(desc);
            }

            this(ref const(ReaderImportType) s) {
                this.mod = s.mod;
                this.name = s.name;
                this.importdesc = ImportDesc(s.importdesc);
            }

        }

        alias Import = SectionT!(ImportType);

        struct TypeIndex {
            uint idx;
            this(const uint typeidx) {
                this.idx = typeidx;
            }

            this(ref const(ReaderSecType!(Section.FUNCTION)) f) {
                idx = f.idx;
            }

            mixin Serialize;
        }

        alias Function = SectionT!(TypeIndex);

        struct TableType {
            Types type;
            Limit limit;
            this(ref const(ReaderSecType!(Section.TABLE)) t) {
                type = t.type;
                limit = Limit(t.limit);
            }

            mixin Serialize;
        }

        alias Table = SectionT!(TableType);

        struct MemoryType {
            Limit limit;
            this(ref const(ReaderSecType!(Section.MEMORY)) m) {
                limit = Limit(m.limit);
            }

            mixin Serialize;
        }

        alias Memory = SectionT!(MemoryType);

        struct GlobalType {
            alias GlobalDesc = ImportType.ImportDesc.GlobalDesc;
            GlobalDesc global;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            this(const GlobalDesc global, immutable(ubyte)[] expr) {
                this.global = global;
                this.expr = expr;
            }

            this(ref const(ReaderSecType!(Section.GLOBAL)) g) {
                global = ImportType.ImportDesc.GlobalDesc(g.global);
                expr = g.expr;
            }

            mixin Serialize;
        }

        alias Global = SectionT!(GlobalType);

        struct ExportType {
            string name;
            IndexType desc;
            uint idx;
            size_t guess_size() const pure nothrow {
                return name.length + uint.sizeof + ImportType.ImportDesc.sizeof;
            }

            this(string name, const uint idx, const IndexType desc = IndexType.FUNC) {
                this.name = name;
                this.desc = desc;
                this.idx = idx;
            }

            this(ref const(ReaderSecType!(Section.EXPORT)) e) {
                name = e.name;
                desc = IndexType(e.desc);
                idx = e.idx;
            }

            mixin Serialize;
        }

        alias Export = SectionT!(ExportType);

        static class Start {
            uint idx;
            alias ReaderStartType = ReaderSections[Section.START];
            this(ref ConstOf!(ReaderStartType) s) {
                idx = s.idx;
            }

            mixin Serialize;
        }

        struct ElementType {
            uint tableidx;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            immutable(uint)[] funcs;
            this(ref const(ReaderSecType!(Section.ELEMENT)) e) {
                tableidx = e.tableidx;
                expr = e.expr;
                funcs = e.funcs;
            }

            mixin Serialize;
        }

        alias Element = SectionT!(ElementType);

        struct CodeType {
            Local[] locals;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            size_t guess_size() const pure nothrow {
                return locals.length * Local.sizeof + expr.length + 2 * uint.sizeof;
            }

            struct Local {
                uint count;
                Types type;
                mixin Serialize;
            }

            static Local[] toLocals(scope const(Types[]) types) pure nothrow {
                Local[] result;
                void compact(const(Types[]) _types) {
                    if (_types.length) {
                        const count = cast(uint) _types.count(_types[0]);
                        result ~= Local(count, _types[0]);
                        compact(_types[count .. $]);
                    }
                }

                return result;

            }

            this(Local[] locals, immutable(ubyte[]) expr) {
                this.locals = locals;
                this.expr = expr;
            }

            this(scope const(Types[]) types, immutable(ubyte[]) expr) {
                this.locals = toLocals(types);
                this.expr = expr;
            }

            @trusted this(ref const(ReaderSecType!(Section.CODE)) c) {
                locals = new Local[c.locals.length];
                foreach (ref l, reader_l; lockstep(locals, c.locals)) {
                    l.count = reader_l.count;
                    l.type = reader_l.type;
                }
                expr = c[].data;
            }

            ExprRange opSlice() const {
                return ExprRange(expr);
            }

            void serialize(ref OutBuffer bout) const {
                auto tmp_out = new OutBuffer;
                tmp_out.reserve(guess_size);
                tmp_out.write(encode(locals.length));
                locals.each!((l) => l.serialize(tmp_out));
                tmp_out.write(expr);
                bout.write(encode(tmp_out.offset));
                bout.write(tmp_out.toBytes);
            }

            immutable(ubyte[]) serialize() const @trusted {
                auto bout = new OutBuffer;
                serialize(bout);
                return assumeUnique(bout.toBytes);
            }
        }

        alias Code = SectionT!(CodeType);

        struct DataType {
            uint idx;
            @Section(Section.CODE) immutable(ubyte)[] expr;
            string base;
            this(ref const(ReaderSecType!(Section.DATA)) d) {
                idx = d.idx;
                expr = d.expr;
                base = d.base;
            }

            mixin Serialize;
        }

        alias Data = SectionT!(DataType);

    }
}

version (none) unittest {
    import std.stdio;
    import std.file;
    import std.exception : assumeUnique;
    import tagion.wavm.Wast;

    @trusted static immutable(ubyte[]) fread(R)(R name, size_t upTo = size_t.max) {
        import std.file : _read = read;

        auto data = cast(ubyte[]) _read(name, upTo);
        // writefln("read data=%s", data);
        return assumeUnique(data);
    }

    //    string filename="../tests/wasm/func_1.wasm";
    string filename = "../tests/wasm/global_1.wasm";
    //    string filename="../tests/wasm/imports_1.wasm";
    //    string filename="../tests/wasm/table_copy_2.wasm";
    //    string filename="../tests/wasm/memory_2.wasm";
    //    string filename="../tests/wasm/start_4.wasm";
    //    string filename="../tests/wasm/address_1.wasm";
    //    string filename="../tests/wasm/data_4.wasm";
    //    string filename="../tests/web_gas_gauge.wasm";//wasm/imports_1.wasm";
    immutable read_data = fread(filename);
    auto wasm_reader = WasmReader(read_data);
    Wast(wasm_reader, stdout).serialize();

    writefln("wasm_reader.serialize=%s", wasm_reader.serialize);
    auto wasm_writer = WasmWriter(wasm_reader);

    writeln("wasm_writer.serialize");
    writefln("wasm_writer.serialize=%s", wasm_writer.serialize);
    assert(wasm_reader.serialize == wasm_writer.serialize);
}
