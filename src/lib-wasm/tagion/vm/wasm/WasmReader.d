module tagion.vm.wasm.WasmReader;

import std.format;
import tagion.vm.wasm.WasmException;
import tagion.vm.wasm.WasmBase;

//import std.stdio;
import std.meta: AliasSeq;
import std.traits: EnumMembers, getUDAs, Unqual, PointerTarget, ForeachType;

import std.bitmanip: binread = read, binwrite = write, peek, Endian;

import std.range.primitives: isInputRange;

import std.conv: to, emplace;
import std.uni: toLower;
import std.exception: assumeUnique;
import std.array: join;
import std.range: enumerate;
import std.format;

@safe
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

    @trusted
    void opCall(InterfaceModule iter) const {
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
                        //                        verbose("E=%s a=%s", E, a);
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
        this(immutable(ubyte[]) data, ref size_t index) {
            lim = cast(Limits) data[index];
            index += Limits.sizeof;
            from = u32(data, index);
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

    @trusted
    static immutable(T[]) Vector(T)(immutable(ubyte[]) data, ref size_t index) {
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

    WasmRange opSlice() const {
        return WasmRange(data);
    }

    static assert(isInputRange!WasmRange);

    struct WasmRange {
        immutable(ubyte[]) data;
        protected size_t _index;
        immutable(string) magic;
        immutable(uint) vernum;
        this(immutable(ubyte[]) data) {
            this.data = data;
            magic = cast(string)(data[0 .. uint.sizeof]);
            _index = uint.sizeof;
            vernum = data[_index .. $].peek!uint(Endian.littleEndian);
            _index += uint.sizeof;
            _index = 2 * uint.sizeof;
        }

        @property bool empty() const pure nothrow {
            return _index >= data.length;
        }

        @property WasmSection front() const pure {
            return WasmSection(data[_index .. $]);
        }

        @property void popFront() {
            size_t u32_size;
            _index += Section.sizeof;
            const size = u32(data, _index);
            _index += size;
        }

        @property size_t index() const pure nothrow {
            return _index;
        }

        struct WasmSection {
            immutable(ubyte[]) data;
            immutable(Section) section;

            this(immutable(ubyte[]) data) pure {
                section = cast(Section) data[0];
                size_t index = Section.sizeof;
                const size = u32(data, index);
                this.data = data[index .. index + size];

                //                debug writefln("section=%s %s", section, data[0..index+size]);
            }

            auto sec(Section S)()
            in {
                assert(S is section);
            }
            do {
                alias T = Sections[S];
                // static if (S is Section.CUSTOM) {
                //     return new ForeachType!(T)(data);
                // }
                // else {
                return new T(data);
                // }
            }

            struct VectorRange(ModuleSection, Element) {
                const ModuleSection owner;
                protected size_t pos;
                protected uint index;
                this(const ModuleSection owner) {
                    this.owner = owner;
                }

                @property Element front() const {
                    return Element(owner.data[pos .. $]);
                }

                @property bool empty() const pure nothrow {
                    return index >= owner.length;
                }

                @property void popFront() {
                    pos += front.size;
                    index++;
                }
            }

            static class SectionT(SecType) {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index;
                    length = u32(data, index);
                    this.data = data[index .. $];
                }

                static assert(isInputRange!SecRange);
                alias SecRange = VectorRange!(SectionT, SecType);

                SecRange opSlice() const {
                    return SecRange(this);
                }

                @trusted
                override string toString() const {
                    string[] result;
                    foreach (i, sec; opSlice.enumerate) {
                        result ~= format("\t%3d %s", i, sec).idup;
                    }
                    return result.join("\n");
                }
            }

            static class Custom {
                immutable(char[]) name;
                immutable(ubyte[]) bytes;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) {
                    size_t index;
                    name = Vector!char(data, index);
                    bytes = data[index .. $];
                    size = data.length;
                }
            }

            struct FuncType {
                immutable(Types) type;
                immutable(Types[]) params;
                immutable(Types[]) results;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) {
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
                        uint typeidx;
                        this(immutable(ubyte[]) data, ref size_t index) {
                            typeidx = u32(data, index);
                        }
                    }

                    struct TableDesc {
                        Types type;
                        Limit limit;
                        this(immutable(ubyte[]) data, ref size_t index) {
                            type = cast(Types) data[index];
                            index += Types.sizeof;
                            limit = Limit(data, index);
                        }
                    }

                    struct MemoryDesc {
                        Limit limit;
                        this(immutable(ubyte[]) data, ref size_t index) {
                            limit = Limit(data, index);
                        }
                    }

                    struct GlobalDesc {
                        Types type;
                        Mutable mut;
                        this(immutable(ubyte[]) data, ref size_t index) {
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

                    this(immutable(ubyte[]) data, ref size_t index) {
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

                this(immutable(ubyte[]) data) {
                    size_t index;
                    mod = Vector!char(data, index);
                    name = Vector!char(data, index);
                    importdesc = ImportDesc(data, index);
                    size = index;
                }

            }

            alias Import = SectionT!(ImportType);

            struct Index {
                immutable(uint) idx;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) {
                    size_t index;
                    idx = u32(data, index);
                    size = index;
                }
            }

            alias Function = SectionT!(Index);

            struct TableType {
                immutable(Types) type;
                immutable(Limit) limit;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) {
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
                this(immutable(ubyte[]) data) {
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
                this(immutable(ubyte[]) data) {
                    size_t index;
                    global = ImportType.ImportDesc.GlobalDesc(data, index);
                    auto range = ExprRange(data[index .. $]);
                    while (!range.empty) {
                        const elm = range.front;
                        if ((elm.code is IR.END) && (elm.level == 0)) {
                            //   range.popFront;
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
                this(immutable(ubyte[]) data) {
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
                immutable(uint) idx;
                this(immutable(ubyte[]) data) {
                    size_t u32_size;
                    idx = u32(data, u32_size);
                }
            }

            struct ElementType {
                immutable(uint) tableidx;
                immutable(ubyte[]) expr;
                immutable(uint[]) funcs;
                immutable(size_t) size;
                static immutable(ubyte[]) exprBlock(immutable(ubyte[]) data) {
                    auto range = ExprRange(data);
                    while (!range.empty) {
                        const elm = range.front;
                        if ((elm.code is IR.END) && (elm.level == 0)) {
                            //range.popFront;
                            return data[0 .. range.index];
                        }
                        range.popFront;
                    }
                    check(0, format("Expression in Element section expected an end code"));
                    assert(0);
                }

                this(immutable(ubyte[]) data) {
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
                this(immutable(ubyte[]) data, ref size_t index) {
                    size = u32(data, index);
                    this.data = data[index .. index + size];
                }

                struct Local {
                    uint count;
                    Types type;
                    this(immutable(ubyte[]) data, ref size_t index) pure {
                        // debug writefln("index=%d data=%s", index, data[index..$]);
                        count = u32(data, index);
                        type = cast(Types) data[index];
                        index += Types.sizeof;
                    }
                }

                LocalRange locals() const {
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
                    this(immutable(ubyte[]) data) {
                        length = u32(data, index);
                        this.data = data;
                        popFront;
                    }

                    protected void set_front(ref size_t local_index) {
                        _local = Local(data, local_index);
                    }

                    @property {
                        const(Local) front() const pure nothrow {
                            return _local;
                        }

                        bool empty() const pure nothrow {
                            return (j > length);
                        }

                        void popFront() {
                            if (j < length) {
                                set_front(index);
                            }
                            j++;
                        }
                    }
                }

                ExprRange opSlice() const {
                    auto range = LocalRange(data);
                    while (!range.empty) {
                        range.popFront;
                    }
                    return ExprRange(data[range.index .. $]);
                }

                this(immutable(ubyte[]) data) {
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

                this(immutable(ubyte[]) data) {
                    size_t index;
                    idx = u32(data, index);
                    auto range = ExprRange(data[index .. $]);
                    while (!range.empty) {
                        const elm = range.front;
                        if ((elm.code is IR.END) && (elm.level == 0)) {
                            // range.popFront;
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
        import std.exception: assumeUnique;

        //      import std.file : fread=read, fwrite=write;

        @trusted
        static immutable(ubyte[]) fread(R)(R name, size_t upTo = size_t.max) {
            import std.file: _read = read;

            auto data = cast(ubyte[]) _read(name, upTo);
            // writefln("read data=%s", data);
            return assumeUnique(data);
        }

        writeln("WAVM Started");
        {
            //string filename="../tests/simple/simple.wasm";
            //string filename="../tests/wasm/custom_1.wasm";
            //string filename="../tests/wasm/func_2.wasm";
            //string filename="../tests/wasm/table_copy_2.wasm"; //../tests/wasm/func_2.wasm";
            //            string filename="../tests/wasm/memory_4.wasm"; //../tests/wasm/func_2.wasm";
            //string filename="../tests/wasm/global_1.wasm";
            //            string filename="../tests/wasm/start_4.wasm";
            //            string filename="../tests/wasm/memory_1.wasm";
            //string filename="../tests/wasm/memory_9.wasm";
            //            string filename="../tests/wasm/global_1.wasm";
            //            string filename="../tests/wasm/imports_2.wasm";
            //string filename="../tests/wasm/table_copy_2.wasm";
            string filename = "../tests/wasm/func_1.wasm";

            immutable code = fread(filename);
            auto wasm = Wasm(code);
            auto range = wasm[];
            writefln("WasmRange %s %d %d", range.empty, wasm.data.length, code.length);
            foreach (a; range) {

                writefln("%s length=%d data=%s", a.section, a.data.length, a.data);
                if (a.section == Section.TYPE) {
                    auto _type = a.sec!(Section.TYPE);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Type types length %d %s", _type.length, _type[]);
                }
                else if (a.section == Section.IMPORT) {
                    auto _import = a.sec!(Section.IMPORT);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Import types length %d %s", _import.length, _import[]);
                }
                else if (a.section == Section.EXPORT) {
                    auto _export = a.sec!(Section.EXPORT);
                    //                    writefln("Function types %s", _type.func_types);
                    //                    writefln("export %s", _export.data);
                    writefln("Export types length %d %s", _export.length, _export[]);
                }
                else if (a.section == Section.FUNCTION) {
                    auto _function = a.sec!(Section.FUNCTION);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Function types length %d %s", _function.length, _function[]);
                }
                else if (a.section == Section.TABLE) {
                    auto _table = a.sec!(Section.TABLE);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Table types length %d %s", _table.length, _table[]);
                    //                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.MEMORY) {
                    auto _memory = a.sec!(Section.MEMORY);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Memory types length %d %s", _memory.length, _memory[]);
                    //                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.GLOBAL) {
                    auto _global = a.sec!(Section.GLOBAL);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Global types length %d %s", _global.length, _global[]);
                    //                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.START) {
                    auto _start = a.sec!(Section.START);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Start types %s", _start);
                    //                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.ELEMENT) {
                    auto _element = a.sec!(Section.ELEMENT);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Element types %s", _element);
                    //                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.CODE) {
                    auto _code = a.sec!(Section.CODE);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Code types length=%s", _code.length);
                    foreach (c; _code[]) {
                        writefln("c.size=%d c.data.length=%d c.locals=%s c[]=%s", c.size, c.data.length, c.locals, c[]);
                    }
                    //                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.DATA) {
                    auto _data = a.sec!(Section.DATA);
                    //                    writefln("Function types %s", _type.func_types);
                    writefln("Data types length=%s", _data.length);
                    foreach (d; _data[]) {
                        writefln("d.size=%d d.data.length=%d d.lodals=%s d[]=%s", d.size, d.init.length, d.init, d[]);
                    }
                    //                    writefln("Table types %s", _table);
                }
            }

        }
    }
}
/+

param-len
|  return-len
| i32 |
|  |  |
00000000  00 61 73 6d 01 00 00 00  01 08 02 60 01 7f 00 60  |.asm.......`...`|
|  |     |          |
magic       version   typesec|   func        func
pack-len

import
|      len i  m   p  o  qq t  s len i  m
00000010  00 00|02 19 01 07 69 6d  70 6f 72 74 73 0d 69 6d  |......imports.im|
len |
25 num-imports
typeidx
| end-19
p  o  r  t  e  d  _  f  u   n  c     | |
00000020  70 6f 72 74 65 64 5f 66  75 6e 63|00 00|03 02 01  |ported_func.....|
|  funcsec
import-type-func

len-export
|   len e  x  p   o  r  t  e  d  _  f  u
00000030  01 07 11 01 0d 65 78 70  6f 72 74 65 64 5f 66 75  |.....exported_fu|
|
export

export-end             42   $i end
n  c       |                    |    |  |
00000040  6e 63 00 01|0a 08 01 06  00 41 2a 10 00 0b|       |nc.......A*...|
|   |           |   call      |
code  |       i32.const         |
code-len                 code-end

+/

/+
 00000000  00 61 73 6d 01 00 00 00  01 0d 03 60 00 01 7f 60  |.asm.......`...`|
 00000010  00 00 60 01 7f 01 7f 02  29 05 01 61 03 65 66 30  |..`.....)..a.ef0|
 00000020  00 00 01 61 03 65 66 31  00 00 01 61 03 65 66 32  |...a.ef1...a.ef2|
 00000030  00 00 01 61 03 65 66 33  00 00 01 61 03 65 66 34  |...a.ef3...a.ef4|
 00000040  00 00 03 08 07 00 00 00  00 00 01 02 04 05 01 70  |...............p|
 00000050  01 1e 1e 07 10 02 04 74  65 73 74 00 0a 05 63 68  |.......test...ch|
 00000060  65 63 6b 00 0b 09 23 04  00 41 02 0b 04 03 01 04  |eck...#..A......|
 00000070  01 01 00 04 02 07 01 08  00 41 0c 0b 05 07 05 02  |.........A......|
 00000080  03 06 01 00 05 05 09 02  07 06 0a 26 07 04 00 41  |...........&...A|
 00000090  05 0b 04 00 41 06 0b 04  00 41 07 0b 04 00 41 08  |....A....A....A.|
 000000a0  0b 04 00 41 09 0b 03 00  01 0b 07 00 20 00 11 00  |...A........ ...|
 000000b0  00 0b                                             |..|
 000000b2
 +/

/++     i32.const                                       end           n:32               bytesize    u:32
 bytesize |        n32   from to    n:32   i32.store8  |   len-locals|    from to    end  |    call |     u:32   u:32
 len  |      |         |      |   |     |        |        |      |      |      |  |      |   |      |  |      |      |
 [3, 15, 0, 65, 0, 65, 0, 45, 0, 0, 65, 1, 106, 58, 0, 0, 11, 8, 0, 65, 0, 45, 0, 0, 15, 11, 8, 0, 16, 0, 16, 0, 16, 0, 11]
 |    n:32  |     |         |       |       |  |      |      |      |         |         |          |     |     end
 |          |  i32.load8_u  |   i32.add   from to   bytesize |      |       return   len-local   call   call
 len-locals    |           i32.const                        i32.const  |
 i32.const                                                  i32.load8_u
 +/

/+
 Type types length 14 [(type (func)), (type (func)), (type (func(param i32))), (type (func(param i32))), (type (func (results i32))), (type (func(param i32) (results i32))), (type (func(param i32) (results i32))), (type (func(param f32 f64))), (type (func(param f32 f64))), (type (func(param f32 f64))), (type (func(param f32 f64))), (type (func(param f32 f64))), (type (func(param f32 f64 i32 f64 i32 i32))), (type (func(param f32 f64 i32)))]
 +/
