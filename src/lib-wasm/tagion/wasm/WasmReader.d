module tagion.wasm.WasmReader;

import tagion.basic.Debug;

import std.array : join;
import std.bitmanip : Endian, peek, binread = read, binwrite = write;
import std.conv : emplace, to;
import std.exception : assumeUnique, assumeWontThrow;
import std.format;
import std.meta : AliasSeq;
import std.range;
import std.algorithm;
import std.array;

//import std.range.primitives : isForwardRange, isInputRange, isRandomAccessRange;
import std.stdio;
import std.traits : EnumMembers, ForeachType, PointerTarget, Unqual, getUDAs;
import std.uni : toLower;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmException;

@safe:
enum ElementMode : ubyte {
    PASSIVE,
    ACTIVE,
    DECLARATIVE,
}

struct WasmReader {
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

    void opCall(InterfaceModule iter) const {
        auto range = opSlice;
        wasm_verbose("WASM '%s'", range.magic);
        wasm_verbose("VERSION %d", range.vernum);
        wasm_verbose("Index %d", range.index);
        while (!range.empty) {
            auto a = range.front;
            scope (failure) {
                wasm_verbose("Failure %s", a);
            }
            with (Section) {
                final switch (a.section) {
                    foreach (E; EnumMembers!(Section)) {
                case E:
                        const sec = a.sec!E;
                        wasm_verbose("Begin(%04x)", range.index);
                        wasm_verbose.down;
                        wasm_verbose("Section(%s) size %d", a.section, a.data.length);
                        wasm_verbose.hex(range.index, a.data);
                        enum code = format(q{iter.%s(sec);}, secname(E));
                        mixin(code);
                        wasm_verbose.println("%s", sec);
                        wasm_verbose.up;
                        wasm_verbose("End");
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

    struct WasmRange {
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

            string toString() const nothrow {
                string info() @trusted {
                    string section_info;
                SectionCase:
                    final switch (section) {
                        static foreach (S; EnumMembers!Section) {
                    case S:
                            break SectionCase;
                        }
                    }
                    return format("Section %s %(%02x %) ", section, data);
                }

                return assumeWontThrow(info());
            }

            auto sec(Section S)() inout pure
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
                this(const ModuleSection owner) pure {
                    this.owner = owner;
                }

                pure {
                    Element front() const {
                        return Element(owner.data[pos .. $]);
                    }

                    bool empty() const nothrow {
                        return index >= owner.length;
                    }

                    void popFront() {
                        pos += front.size;
                        index++;
                    }

                    VectorRange save() nothrow {
                        VectorRange result = this;
                        return result;
                    }

                }
                const(Element) opIndex(const size_t index) const pure {
                    auto range = VectorRange(owner);
                    size_t i;
                    while (!range.empty) {
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

                final string info() const {
                    string[] result;
                    foreach (i, sec; opSlice.enumerate) {
                        result ~= format("\t%3d %s", i, sec).idup;
                    }
                    return result.join("\n");
                }

                override string toString() const {
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
                final string info() const {
                    return "<< Custom >>";
                }

                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    name = Vector!char(data, index);
                    import LEB128 = tagion.utils.LEB128;

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

            struct FuncIndex {
                immutable(uint) idx; /// Function index 
                immutable(size_t) size;
                this(immutable(ubyte[]) data) pure nothrow {
                    size_t index;
                    idx = u32(data, index);
                    size = index;
                }
            }

            alias Function = SectionT!(FuncIndex);

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
                this(immutable(ubyte[]) data) pure {
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
                this(immutable(ubyte[]) data) pure {
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
                final string info() const {
                    return format("Start idx %d", idx);
                }

                this(immutable(ubyte[]) data) pure nothrow {
                    size_t u32_size;
                    idx = u32(data, u32_size);
                }
            }

            static ElementMode elementMode(const uint select) pure nothrow @nogc {
                if (select & 0x1) {
                    if (select & 0x2) {
                        return ElementMode.DECLARATIVE;
                    }
                    return ElementMode.PASSIVE;
                }
                return ElementMode.ACTIVE;
            }

            struct ElementType {
                immutable(uint) tableidx; /// x:tableidx
                immutable(ubyte[]) expr; /// e:expr
                immutable(ubyte[][]) exprs; /// el*:exprs
                immutable(uint[]) funcs; /// y*:vec(funcidx)
                immutable(uint) select; /// Element mode
                immutable(uint) elemkind; /// et:elemkind
                immutable(size_t) size;
                immutable(Types) reftype;
                static immutable(ubyte[]) exprBlock(immutable(ubyte[]) data, ref size_t index) pure {
                    auto range = ExprRange(data[index .. $]);
                    scope (exit) {
                        index += range.index;
                    }
                    if (data[0] is 0) {
                        return null;
                    }
                    while (!range.empty) {
                        const elm = range.front;
                        if ((elm.code is IR.END) && (elm.level == 0)) {
                            return data[0 .. range.index];
                        }
                        range.popFront;
                    }
                    check(0, format("Expression in Element section expected an end code"));
                    assert(0);
                }

                enum MAX_ELEMENT_EXPRESSION = 0x1000;
                static immutable(ubyte[])[] exprBlocks(immutable(ubyte[]) data,
                        ref size_t index) pure {
                    const expressions = u32(data, index);
                    check(expressions <= MAX_ELEMENT_EXPRESSION, "Format too many element expressioins");

                    return expressions
                        .iota
                        .map!(n => exprBlock(data, index))
                        .array;
                }

                this(immutable(ubyte[]) data) pure {
                    size_t index;
                    uint _tableidx;
                    uint _elemkind;
                    Types _reftype;
                    immutable(uint)[] _funcs;
                    immutable(ubyte)[] _expr;
                    immutable(ubyte[])[] _exprs;
                    select = u32(data, index);
                    __write("WasmRead select %d %(%02x %)", select, data.take(10));
                    void init_elementmode() {
                        // Mode comment is from Webassembly spec Modules/Element Section 
                        switch (select) {
                        case 0: // 0:u32 e:expr y*:vec(funcidx)
                            _expr = exprBlock(data, index);
                            _funcs = Vector!uint(data, index);
                            break;
                        case 1: // 1:u32 et:elemkind y*:vec(funcidx) -> passive mode
                            _elemkind = u32(data, index);
                            _funcs = Vector!uint(data, index);
                            break;
                        case 2: // 2:u32 x:tableidx y*:vec(funcidix)
                            _tableidx = u32(data, index);
                            _expr = exprBlock(data, index);
                            _elemkind = u32(data, index);
                            _funcs = Vector!uint(data, index);
                            break;
                        case 3: // 3:u32 et:elemkind y*:vec(funcidix)
                            _elemkind = u32(data, index);
                            _funcs = Vector!uint(data, index);
                            break;
                        case 4: // 4:u32 e:expr el*:vec(expr)
                            _expr = exprBlock(data, index);
                            _funcs = Vector!uint(data, index);
                            break;
                        case 5: // 5:u32 et:reftype el*:vec(expr)
                            _reftype = cast(Types)(data[index++]);
                            _exprs = exprBlocks(data, index);
                            break;
                        case 6: // x:tableidx e:expr et:reftype el*:vec(expr) 
                            _tableidx = u32(data, index);
                            _expr = exprBlock(data, index);
                            _reftype = cast(Types) data[index++];
                            _exprs = exprBlocks(data, index);
                            break;
                        case 7: // et:reftype el*:vec(expr) 
                            _reftype = cast(Types) data[index++];
                            _exprs = exprBlocks(data, index);
                            break;
                        default:
                            check(0, format("Invalid element mode %d", select));
                        }
                    }

                    init_elementmode;
                    expr = _expr;
                    funcs = _funcs;
                    elemkind = _elemkind;
                    tableidx = _tableidx;
                    exprs = _exprs;
                    reftype = _reftype;
                    size = index;
                }

                ExprRange opSlice() const {
                    return ExprRange(expr);
                }

                ElementMode mode() const pure nothrow @nogc {
                    return elementMode(select);
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
                immutable uint memidx;
                immutable(ubyte[]) expr;
                immutable(char[]) base; // init value
                immutable(size_t) size;
                immutable DataMode mode;

                this(immutable(ubyte[]) data) pure {
                    size_t index;
                    mode = decode!(DataMode)(data, index);
                    uint _memidx;
                    immutable(ubyte)[] _data;
                    void initialize() {
                        final switch (mode) {
                        case DataMode.ACTIVE_INDEX:
                            _memidx = u32(data, index);
                            goto case;
                        case DataMode.ACTIVE:
                            auto range = ExprRange(data[index .. $]);
                            while (!range.empty) {
                                const elm = range.front;
                                if ((elm.code is IR.END) && (elm.level == 0)) {
                                    break;
                                }
                                range.popFront;
                            }
                            _data = range.data[0 .. range.index];
                            index += range.index;
                            break;
                        case DataMode.PASSIVE:
                            _memidx = u32(data, index);
                            break;
                        }
                    }

                    initialize;
                    memidx = _memidx;
                    expr = _data;
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

}
