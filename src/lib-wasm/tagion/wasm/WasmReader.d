module tagion.wasm.WasmReader;

import std.stdio;

import std.format;
import tagion.wasm.WasmException;
import tagion.wasm.WasmBase;

import std.meta : AliasSeq;
import std.traits : EnumMembers, getUDAs, Unqual, PointerTarget, ForeachType;

import std.bitmanip : binread = read, binwrite = write, peek, Endian;

import std.range.primitives : isInputRange, isForwardRange, isRandomAccessRange;

import std.conv : to, emplace;
import std.uni : toLower;
import std.exception : assumeUnique;
import std.array : join;
import std.range : enumerate;
import std.format;

@safe struct WasmReader {
    protected {
        immutable(ubyte)[] _data;
    }

    immutable(ubyte[]) data() const pure nothrow {
        return _data;
    }

    alias serialize = data;

    this(immutable(ubyte[]) data) pure nothrow {
        _data = data;
    }

    alias Sections = SectionsT!(WasmRange.WasmSection);

    alias InterfaceModule = InterfaceModuleT!(Sections);

    @trusted void opCall(InterfaceModule iter) const {
        auto range = opSlice;
        verbose("WASM '%s'", range.magic);
        verbose("VERSION %d", range.vernum);
        verbose("Index %d", range.index);

        while (!range.empty) {
            auto a = range.front;
            with (Section) {
                final switch (a.section) {
                    foreach (E; EnumMembers!(Section)) {
                case E:
                        const sec = a.sec!E;
                        verbose("Begin(%d)", range.index);
                        verbose.down;
                        verbose("Section(%s) size %d", a.section, a.data.length);
                        verbose.hex(range.index, a.data);
                        enum code = format(q{iter.%s(sec);}, secname(E));
                        mixin(code);
                        verbose.println("%s", sec);
                        verbose.up;
                        verbose("End");
                        break;
                    }
                }
            }
            range.popFront;
        }
    }

    struct Limit {
        Limits lim;
        uint from;
        uint to;
        this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
            lim = cast(Limits) data[index];
            index += Limits.sizeof;
            from = u32(data, index); // LEB128 -> uint.max
            const uint get_to(const uint lim) {
                with (Limits) {
                    final switch (lim) {
                    case INFINITE:
                        return to.max;
                    case RANGE:
                        return u32(data, index);
                    }
                }
            }

            to = get_to(lim);
        }
    }

    @trusted static immutable(T[]) Vector(T)(immutable(ubyte[]) data, ref size_t index) {
        immutable len = u32(data, index);
        static if (T.sizeof is ubyte.sizeof) {
            immutable vec_mem = data[index .. index + len * T.sizeof];
            index += len * T.sizeof;
            immutable result = cast(immutable(T*))(vec_mem.ptr);
            return result[0 .. len];
        }
        else {
            auto result = new T[len];
            foreach (ref a; result) {
                a = decode!T(data, index);
            }
            return assumeUnique(result);
        }
    }

    WasmRange opSlice() const pure nothrow {
        return WasmRange(data);
    }

    static assert(isInputRange!WasmRange);
    static assert(isForwardRange!WasmRange);
    //static assert(isRandomAccessRange!WasmRange);

    auto get(Section S)() const nothrow {
        alias T = Sections[S];
        auto range = opSlice;
        auto sec = range[S];
        import std.exception;

        debug {
            assumeWontThrow(
            { writefln("sec.data=%s", sec.data); }
            );
        }

        return new T(sec.data);
    }

    @safe struct WasmRange {
        immutable(ubyte[]) data;
        protected size_t _index;
        immutable(string) magic;
        immutable(uint) vernum;
        this(immutable(ubyte[]) data) pure nothrow @nogc @trusted {
            this.data = data;
            magic = cast(string)(data[0 .. uint.sizeof]);
            _index = uint.sizeof;
            vernum = data[_index .. $].peek!(uint, Endian.littleEndian);
            _index += uint.sizeof;
            _index = 2 * uint.sizeof;
        }

        pure nothrow {
            bool empty() const @nogc {
                return _index >= data.length;
            }

            WasmSection front() const @nogc {
                return WasmSection(data[_index .. $]);
            }

            void popFront() @nogc {
                _index += Section.sizeof;
                const size = u32(data, _index);
                _index += size;
            }

            WasmRange save() @nogc {
                WasmRange result = this;
                return result;
            }

            WasmSection opIndex(const Section index) const
            in {
                assert(index < EnumMembers!(Section).length);
            }
            do {
                auto index_range = WasmRange(data);
                //                (() @trusted {
                foreach (ref sec; index_range) {
                    if (index == sec.section) {
                        return sec;
                    }
                    else if (index < sec.section) {
                        break;
                    }
                }
                return WasmSection.emptySection(index);
            }

            size_t index() const @nogc {
                return _index;
            }

        }

        @nogc struct WasmSection {
            immutable(ubyte[]) data;
            immutable(Section) section;

            static WasmSection emptySection(const Section sectype) pure nothrow {
                immutable(ubyte[]) data = [sectype, 0];
                return WasmSection(data);
            }

            this(immutable(ubyte[]) data) @nogc pure nothrow {
                section = cast(Section) data[0];
                size_t index = Section.sizeof;
                const size = u32(data, index);
                this.data = data[index .. index + size];
            }

            auto sec(Section S)() pure
            in {
                assert(S is section);
            }
            do {
                alias T = Sections[S];
                return new T(data);
            }

            @nogc struct VectorRange(ModuleSection, Element) {
                const ModuleSection owner;
                protected size_t pos;
                protected uint index;
                this(const ModuleSection owner) pure nothrow {
                    this.owner = owner;
                }

                pure nothrow {
                    Element front() const {
                        return Element(owner.data[pos .. $]);
                    }

                    bool empty() const {
                        return index >= owner.length;
                    }

                    void popFront() {
                        pos += front.size;
                        index++;
                    }

                    VectorRange save() {
                        VectorRange result = this;
                        return result;
                    }

                }
                const(Element) opIndex(const size_t index) const pure {
                    auto range = VectorRange(owner);
                    size_t i;
                    while (!range.empty) {
                        //                    foreach (i, ref e; range.enumerate) {
                        if (i is index) {
                            return range.front;
                        }
                        range.popFront;
                        i++;
                    }
                    throw new WasmException(format!"Index %d out of range"(index));
                    assert(0);
                }
            }

            static class SectionT(SecType) {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) @nogc pure nothrow {
                    size_t index;
                    length = u32(data, index);
                    this.data = data[index .. $];
                }

                protected this(const(SectionT) that) @nogc pure nothrow {
                    data = that.data;
                    length = that.length;
                }
                // static assert(isInputRange!SecRange);
                // static assert(isForwardRange!SecRange);
                alias SecRange = VectorRange!(SectionT, SecType);
                SecRange opSlice() const pure nothrow {
                    return SecRange(this);
                }

                SecType opIndex(const size_t index) const pure {
                    return SecRange(this).opIndex(index);
                }

                SectionT dup() const pure nothrow {
                    return new SectionT(this);
                }

                @trusted override string toString() const {
                    string[] result;
                    foreach (i, sec; opSlice.enumerate) {
                        result ~= format("\t%3d %s", i, sec).idup;
                    }
                    return result.join("\n");
                }
            }

            static class Custom {
                import tagion.hibon.Document;

                immutable(char[]) name;
                immutable(ubyte[]) bytes;
                const(Document) doc;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    name = Vector!char(data, index);
                    import LEB128 = tagion.utils.LEB128;
                    import tagion.basic.Debug;

                    __write("WasmReader %s", LEB128.decode!uint(data[index .. $]));
                    doc = Document(data[index .. $]);
                    index += LEB128.decode!uint(data[index .. $]).size;
                    bytes = data[index .. $];
                    size = data.length;
                }
            }

            struct FuncType {
                immutable(Types) type;
                immutable(Types[]) params;
                immutable(Types[]) results;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    type = cast(Types) data[0];
                    size_t index = Types.sizeof;
                    params = Vector!Types(data, index);
                    results = Vector!Types(data, index);
                    size = index;
                }
            }

            alias Type = SectionT!(FuncType);

            struct ImportType {
                immutable(char[]) mod;
                immutable(char[]) name;
                immutable(ImportDesc) importdesc;
                immutable(size_t) size;
                struct ImportDesc {
                    struct FuncDesc {
                        uint funcidx;
                        this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
                            funcidx = u32(data, index);
                        }
                    }

                    struct TableDesc {
                        Types type;
                        Limit limit;
                        this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
                            type = cast(Types) data[index];
                            index += Types.sizeof;
                            limit = Limit(data, index);
                        }
                    }

                    struct MemoryDesc {
                        Limit limit;
                        this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
                            limit = Limit(data, index);
                        }
                    }

                    struct GlobalDesc {
                        Types type;
                        Mutable mut;
                        this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
                            type = cast(Types) data[index];
                            index += Types.sizeof;
                            mut = cast(Mutable) data[index];
                            index += Mutable.sizeof;
                        }
                    }

                    protected union {
                        @(IndexType.FUNC) FuncDesc _funcdesc;
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
                        foreach (E; EnumMembers!IndexType) {
                            static if (E is IType) {
                                enum code = format("return _%sdesc;", toLower(E.to!string));
                                mixin(code);
                            }
                        }
                    }

                    @property IndexType desc() const pure nothrow {
                        return _desc;
                    }

                    this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
                        _desc = cast(IndexType) data[index];
                        index += IndexType.sizeof;
                        with (IndexType) {
                            final switch (_desc) {
                            case FUNC:
                                _funcdesc = FuncDesc(data, index);
                                break;
                            case TABLE:
                                _tabledesc = TableDesc(data, index);
                                break;
                            case MEMORY:
                                _memorydesc = MemoryDesc(data, index);
                                break;
                            case GLOBAL:
                                _globaldesc = GlobalDesc(data, index);
                                break;
                            }
                        }
                    }

                }

                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    mod = Vector!char(data, index);
                    name = Vector!char(data, index);
                    importdesc = ImportDesc(data, index);
                    size = index;
                }

            }

            alias Import = SectionT!(ImportType);

            struct TypeIndex {
                immutable(uint) idx;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    idx = u32(data, index);
                    size = index;
                }
            }

            alias Function = SectionT!(TypeIndex);

            struct TableType {
                immutable(Types) type;
                immutable(Limit) limit;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    type = cast(Types) data[0];
                    size_t index = Types.sizeof;
                    limit = Limit(data, index);
                    size = index;
                }

            }

            alias Table = SectionT!(TableType);

            struct MemoryType {
                immutable(Limit) limit;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    limit = Limit(data, index);
                    size = index;
                }
            }

            alias Memory = SectionT!(MemoryType);

            struct GlobalType {
                immutable(ImportType.ImportDesc.GlobalDesc) global;
                immutable(ubyte[]) expr;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    global = ImportType.ImportDesc.GlobalDesc(data, index);
                    auto range = ExprRange(data[index .. $]);
                    while (!range.empty) {
                        const elm = range.front;
                        if ((elm.code is IR.END) && (elm.level == 0)) {
                            break;
                        }
                        range.popFront;
                    }
                    expr = range.data[0 .. range.index];
                    index += range.index;
                    size = index;
                }

                ExprRange opSlice() const {
                    return ExprRange(expr);
                }
            }

            alias Global = SectionT!(GlobalType);

            struct ExportType {
                immutable(char[]) name;
                immutable(IndexType) desc;
                immutable(uint) idx;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    name = Vector!char(data, index);
                    desc = cast(IndexType) data[index];
                    index += IndexType.sizeof;
                    idx = u32(data, index);
                    size = index;
                }
            }

            alias Export = SectionT!(ExportType);

            static class Start {
                immutable(uint) idx; // Function index
                this(immutable(ubyte[]) data) pure nothrow {
                    size_t u32_size;
                    idx = u32(data, u32_size);
                }
            }

            struct ElementType {
                immutable(uint) tableidx;
                immutable(ubyte[]) expr;
                immutable(uint[]) funcs;
                immutable(size_t) size;
                static immutable(ubyte[]) exprBlock(immutable(ubyte[]) data) pure nothrow {
                    auto range = ExprRange(data);
                    while (!range.empty) {
                        const elm = range.front;
                        if ((elm.code is IR.END) && (elm.level == 0)) {
                            return data[0 .. range.index];
                        }
                        range.popFront;
                    }
                    //check(0, format("Expression in Element section expected an end code"));
                    assert(0);
                }

                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    tableidx = u32(data, index);
                    expr = exprBlock(data[index .. $]);
                    index += expr.length;
                    funcs = Vector!uint(data, index);
                    size = index;
                }

                ExprRange opSlice() const {
                    return ExprRange(expr);
                }
            }

            alias Element = SectionT!(ElementType);

            struct CodeType {
                immutable size_t size;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
                    size = u32(data, index);
                    this.data = data[index .. index + size];
                }

                struct Local {
                    uint count;
                    Types type;
                    this(immutable(ubyte[]) data, ref size_t index) pure nothrow {
                        count = u32(data, index);
                        type = cast(Types) data[index];
                        index += Types.sizeof;
                    }
                }

                LocalRange locals() const pure nothrow {
                    return LocalRange(data);
                }

                static assert(isInputRange!LocalRange);
                struct LocalRange {
                    immutable uint length;
                    immutable(ubyte[]) data;
                    private {
                        size_t index;
                        uint j;
                    }

                    protected Local _local;
                    this(immutable(ubyte[]) data) pure nothrow {
                        length = u32(data, index);
                        this.data = data;
                        popFront;
                    }

                    protected void set_front(ref size_t local_index) pure nothrow {
                        _local = Local(data, local_index);
                    }

                    @property {
                        const(Local) front() const pure nothrow {
                            return _local;
                        }

                        bool empty() const pure nothrow {
                            return (j > length);
                        }

                        void popFront() pure nothrow {
                            if (j < length) {
                                set_front(index);
                            }
                            j++;
                        }
                    }
                }

                ExprRange opSlice() pure const {
                    auto range = LocalRange(data);
                    while (!range.empty) {
                        range.popFront;
                    }
                    return ExprRange(data[range.index .. $]);
                }

                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    auto byte_size = u32(data, index);
                    this.data = data[index .. index + byte_size];
                    index += byte_size;
                    size = index;
                }

            }

            alias Code = SectionT!(CodeType);

            struct DataType {
                immutable uint idx;
                immutable(ubyte[]) expr;
                immutable(char[]) base; // init value
                immutable(size_t) size;

                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    idx = u32(data, index);
                    auto range = ExprRange(data[index .. $]);
                    while (!range.empty) {
                        const elm = range.front;
                        if ((elm.code is IR.END) && (elm.level == 0)) {
                            break;
                        }
                        range.popFront;
                    }
                    expr = range.data[0 .. range.index];
                    index += range.index;
                    base = Vector!char(data, index);
                    size = index;
                }

                ExprRange opSlice() const {
                    return ExprRange(expr);
                }
            }

            alias Data = SectionT!(DataType);

        }
    }

    version (none) unittest {
        import std.stdio;
        import std.file;
        import std.exception : assumeUnique;

        @trusted static immutable(ubyte[]) fread(R)(R name, size_t upTo = size_t.max) {
            import std.file : _read = read;

            auto data = cast(ubyte[]) _read(name, upTo);
            return assumeUnique(data);
        }

        writeln("WAVM Started");
        {
            immutable code = fread(filename);
            auto wasm = Wasm(code);
            auto range = wasm[];
            writefln("WasmRange %s %d %d", range.empty, wasm.data.length, code.length);
            foreach (a; range) {

                writefln("%s length=%d data=%s", a.section, a.data.length, a.data);
                if (a.section == Section.TYPE) {
                    auto _type = a.sec!(Section.TYPE);
                    writefln("Type types length %d %s", _type.length, _type[]);
                }
                else if (a.section == Section.IMPORT) {
                    auto _import = a.sec!(Section.IMPORT);
                    writefln("Import types length %d %s", _import.length, _import[]);
                }
                else if (a.section == Section.EXPORT) {
                    auto _export = a.sec!(Section.EXPORT);
                    writefln("Export types length %d %s", _export.length, _export[]);
                }
                else if (a.section == Section.FUNCTION) {
                    auto _function = a.sec!(Section.FUNCTION);
                    writefln("Function types length %d %s", _function.length, _function[]);
                }
                else if (a.section == Section.TABLE) {
                    auto _table = a.sec!(Section.TABLE);
                    writefln("Table types length %d %s", _table.length, _table[]);
                }
                else if (a.section == Section.MEMORY) {
                    auto _memory = a.sec!(Section.MEMORY);
                    writefln("Memory types length %d %s", _memory.length, _memory[]);
                }
                else if (a.section == Section.GLOBAL) {
                    auto _global = a.sec!(Section.GLOBAL);
                    writefln("Global types length %d %s", _global.length, _global[]);
                }
                else if (a.section == Section.START) {
                    auto _start = a.sec!(Section.START);
                    writefln("Start types %s", _start);
                }
                else if (a.section == Section.ELEMENT) {
                    auto _element = a.sec!(Section.ELEMENT);
                    writefln("Element types %s", _element);
                }
                else if (a.section == Section.CODE) {
                    auto _code = a.sec!(Section.CODE);
                    writefln("Code types length=%s", _code.length);
                    foreach (c; _code[]) {
                        writefln("c.size=%d c.data.length=%d c.locals=%s c[]=%s",
                                c.size, c.data.length, c.locals, c[]);
                    }
                }
                else if (a.section == Section.DATA) {
                    auto _data = a.sec!(Section.DATA);
                    writefln("Data types length=%s", _data.length);
                    foreach (d; _data[]) {
                        writefln("d.size=%d d.data.length=%d d.lodals=%s d[]=%s",
                                d.size, d.init.length, d.init, d[]);
                    }
                }
            }

        }
    }
}
