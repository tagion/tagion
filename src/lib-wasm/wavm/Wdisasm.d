module wavm.Wdisasm;

import std.format;
import std.stdio;
import std.traits : EnumMembers;
import std.typecons : Tuple;
import std.uni : toLower;
import std.conv : to;
import std.range.primitives : isOutputRange;

import wavm.Wasm;

struct Wdisasm {
    protected Wasm wasm;
    @disable this();
    this(const Wasm wasm) {
        this.wasm=wasm;
    }
    static bool simple_error(const bool flag, string text) {
        if (!flag) {
            stderr.writeln("Error %s", text);
        }
        return flag;
    }

    alias WasmSection=Wasm.WasmRange.WasmSection;
    alias Section=Wasm.Section;

    protected static string secname(immutable Section s) {
        import std.exception : assumeUnique;
        return assumeUnique(format("%s_sec", toLower(s.to!string)));
    }


    alias Module=Tuple!(
        const(WasmSection.Custom)[],  secname(Section.CUSTOM),
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

    alias ModuleIterator=void delegate(const Section sec, ref scope const(Module) mod);

    interface InterfaceModule {
        void custom_sec(ref scope const(Module) mod);
        void type_sec(ref scope const(Module) mod);
        void import_sec(ref scope const(Module) mod);
        void function_sec(ref scope const(Module) mod);
        void table_sec(ref scope const(Module) mod);
        void memory_sec(ref scope const(Module) mod);
        void global_sec(ref scope const(Module) mod);
        void export_sec(ref scope const(Module) mod);
        void start_sec(ref scope const(Module) mod);
        void element_sec(ref scope const(Module) mod);
        void code_sec(ref scope const(Module) mod);
        void data_sec(ref scope const(Module) mod);
    }

    shared static unittest {
        template NoPtr(T) {
            T x;
            alias NoPtr=typeof(x[0]);
        }


        import std.traits : Unqual;
        import std.meta : staticMap;
        alias NoPtrModule=staticMap!(NoPtr, Module.Types);
        alias unqualModule=staticMap!(Unqual, NoPtrModule);
        static assert(is(unqualModule == WasmSection.Sections));
    }

    void opCall(T)(T iter) if (is(T==ModuleIterator) || is(T:InterfaceModule)) {
        scope Module mod;
        Wasm.Section previous_sec;
        foreach(a; wasm[]) {
            with(Wasm.Section) {
                if ((a.section !is CUSTOM) && (simple_error(previous_sec < a.section, "Bad order"))) {
                    previous_sec=a.section;
                    final switch(a.section) {
                        foreach(E; EnumMembers!(Wasm.Section)) {
                        case E:
                            static if (E is CUSTOM) {
                                mod.custom_sec~=a.sec!CUSTOM;
                            }
                            else {
                                const sec=a.sec!E;
                                mod[E]=&sec;
                            }
                            static if (is(T==ModuleIterator)) {
                                iter(a.section, mod);
                            }
                            else {
                                enum code=format(q{iter.%s(mod);}, secname(E));
                                pragma(msg, code);
                                mixin(code);
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}


WastT!Output Wast(Output)(Wdisasm dasm, Output output) {
    return new WastT!Output(dasm, output);
}

class WastT(Output) : Wdisasm.InterfaceModule {
    alias Module=Wdisasm.Module;
    alias ExprRange=Wasm.WasmRange.WasmSection.ExprRange;
    alias Section=Wasm.Section;
    alias IRType=Wasm.IRType;
    alias IR=Wasm.IR;
    alias Types=Wasm.Types;
    protected {
        Output output;
        Wdisasm dasm;
        string indent;
        string spacer;
    }

    this(Wdisasm dasm, Output output, string spacer="  ") { //static if (isOutputRange!Ouput) {
        this.output=output;
        this.dasm=dasm;
        this.spacer=spacer;
    }

    void custom_sec(ref scope const(Module) mod) {
    }

    void type_sec(ref scope const(Module) mod) {
    }

    void import_sec(ref scope const(Module) mod) {
    }

    void function_sec(ref scope const(Module) mod) {
    }

    void table_sec(ref scope const(Module) mod) {
    }

    void memory_sec(ref scope const(Module) mod) {
    }

    void global_sec(ref scope const(Module) mod) {
    }

    void export_sec(ref scope const(Module) mod) {
    }

    void element_sec(ref scope const(Module) mod) {
    }

    void start_sec(ref scope const(Module) mod) {
    }

    void code_sec(ref scope const(Module) mod) {
        auto _code=*mod.code_sec;
        output.writefln("Code types _code.length=%s", _code.length);
        uint count=1000;
        uint block_count;
        const(ExprRange.IRElement) block(ref ExprRange expr, const(string) indent, const uint level=0) {
            string block_comment;
            while (!expr.empty) {
                const elm=expr.front;
                const instr=Wasm.instrTable[elm.code];
                if (count==0) {
                    return elm;
                }
                count--;

                with(IRType) {
                    // if (instr.irtype is END) {
                    //     return;
                    // }
                    // else {
                        expr.popFront;
                    // }
//                    output.writefln("%s<%s>", indent, elm);
                    final switch(instr.irtype) {
                    case CODE:
                        output.writefln("%s(%s)", indent, instr.name);
                        break;
                    case BLOCK:
                        static string block_result_type() (const Types t) {
                            with(Types) {
                                switch(t) {
                                case I32, I64, F32, F64, FUNCREF:
                                    return format(" (result %s)", Wasm.typesName(t));
                                case EMPTY:
                                    return null;
                                default:
                                    check(0, format("Block Illegal result type %s for a block", t));
                                // empty
                                }
                            }
                            assert(0);
                        }
                        block_comment=format(";; block %d", block_count);
                        block_count++;
                        output.writefln("%s(%s%s %s", indent, instr.name, block_result_type(elm.types[0]), block_comment);
                        const end_elm=block(expr, indent~spacer, level+1);
                        // writefln("expr.empty=%s", expr.empty);
                        // const end_elm=expr.front;
                        //writefln(">>>end %s", end_elm);
                        const end_instr=Wasm.instrTable[end_elm.code];
                        //check(end_elm.code is IR.END, format("(begin expected an end) but got an (%s)", end_instr.name));
                        output.writefln("%s) %s count=%d", indent, block_comment, count);
                        break;
                    case BRANCH:
                        output.writefln("%s[%s %s] ;; %s", indent, instr.name, elm.args[0], elm);
                        break;
                    case BRANCH_TABLE:
                        output.writefln("%s[%s] ;; %s", indent, instr.name, elm);
                        break;
                    case CALL:
                        output.writefln("%s(%s %s)", indent, instr.name, elm.args[0]);
                        break;
                    case CALL_INDIRECT:
                        output.writefln("%s[%s] ;; %s", indent, instr.name, elm);
                        break;
                    case LOCAL:
                        output.writefln("%s(%s %s)", indent, instr.name, elm.args[0]);
                        break;
                    case GLOBAL:
                        output.writefln("%s[%s] ;; %s", indent, instr.name, elm);
                        break;
                    case MEMORY:
                        output.writefln("%s[%s] ;; %s", indent, instr.name, elm);
                        break;
                    case MEMOP:
                        output.writefln("%s[%s] ;; %s", indent, instr.name, elm);
                        break;
                    case CONST:

                        output.writefln("%s[%s %s] ;; %s", indent, instr.name, elm.args[0], elm);
                        break;
                    case END:
                        writeln("Retrun END");
                        return elm;
                        //assert(0);
                        //return;
                        //break;
                    }
                }
                // if (instr.irtype is IRType.BLOCK) {
                //     block(expr, indent~spacer, level+1);
                // }
                // else if (instr.irtype is IRType.END) {
                //     return;
                // }
            }
            // check(0, "Block missing end");
            // assert(0);
            return ExprRange.IRElement(IR.END, level);
        }
        writefln("code.data=%s", _code.data);
        foreach(c; _code[]) {
            auto expr=c[];
            writefln(">expr.data=%s", expr.data);
            block(expr,indent);
            // foreach(elm; c[]) {

            //     output.writefln("<%s>", elm);
            // }
//            output.writefln("c.size=%d c.data.length=%d c.locals=%s c[]=%s", c.size, c.data.length, c.locals, c[]);
        }
    }

    void data_sec(ref scope const(Module) mod) {
    }


    Output serialize() {
        output.writeln("(module");
        indent=spacer;
        scope(exit) {
            output.writeln(")");
        }
        dasm(this);
        return output;
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

    string filename="../tests/wasm/func_1.wasm";

    immutable code=fread(filename);
    auto wasm=Wasm(code);
    auto dasm=Wdisasm(wasm);
    Wast(dasm, stdout).serialize();
//    auto output=Wast

}

/+
[
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
4, 1, 1, 127, 11,
4, 1, 1, 127, 11,
8, 3, 1, 127, 1, 124, 1, 126, 11,
6, 2, 1, 127, 1, 124, 11,
12, 5, 1, 127, 1, 125, 1, 126, 1, 127, 1, 124, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
2, 0, 11,
3, 0, 0, 11,
2, 0, 11,
4, 0, 65, 0, 11,
2, 0, 11, 4, 0, 65, 0, 11,
4, 0, 65, 0, 11, 2, 0, 11,
4, 0, 65, 0, 11, 2, 0, 11,
2, 0, 11,
16, 6, 1, 125, 1, 127, 1, 126, 1, 127, 1, 124, 1, 127, 0, 0, 11,
16, 6,
1, 125,
1, 127,
1, 126,
1, 127,
1, 124,
1, 127,
0, 0, 11,

6, 1,
2, 127,
32, 0,
11,

6, 1, 2, 126, 32, 0, 11,
6, 1, 2, 125, 32, 0, 11,
6, 1, 2, 124, 32, 0, 11,
6, 1, 2, 127, 32, 1, 11,
6, 1, 2, 126, 32, 1, 11,
6, 1, 2, 125, 32, 1, 11,
6, 1, 2, 124, 32, 1, 11,
40, 6, 1, 125, 1, 127, 1, 126, 1, 127, 1, 124, 1, 127, 32, 0, 140, 26, 32, 1, 69, 26, 32, 2, 80, 26, 32, 3, 69, 26, 32, 4, 154, 26, 32, 5, 69, 26, 32, 4, 11,
4, 0, 32, 0, 11,
4, 0, 32, 0, 11,
4, 0, 32, 0, 11,
4, 0, 32, 0, 11,
4, 0, 32, 1, 11,
4, 0, 32, 1, 11,
4, 0, 32, 1, 11,
4, 0, 32, 1, 11,
28, 0, 32, 0, 140, 26, 32, 1, 69, 26, 32, 2, 80, 26, 32, 3, 69, 26, 32, 4, 154, 26, 32, 5, 69, 26, 32, 4, 11,
2, 0, 11,
4, 0, 16, 0, 11,
5, 0, 65, 205, 0, 11, 5, 0, 66, 225, 60, 11,
7, 0, 67, 102, 102, 155, 66, 11,
11, 0, 68, 225, 122, 20, 174, 71, 113, 83, 64, 11,
9, 0, 2, 64, 16, 0, 16, 0, 11, 11,
10, 0, 2, 127, 16, 0, 65, 205, 0, 11, 11,
3, 0, 15, 11,
6, 0, 65, 206, 0, 15, 11,
6, 0, 66, 198, 61, 15, 11,
8, 0, 67, 102, 102, 157, 66, 15, 11,
12, 0, 68, 82, 184, 30, 133, 235, 177, 83, 64, 15, 11,
11, 0, 2, 127, 16, 0, 65, 205, 0, 11,
15, 11, 4, 0, 12, 0, 11, 7, 0, 65, 207, 0, 12, 0, 11,
7, 0, 66, 171, 62, 12, 0, 11,
9, 0, 67, 205, 204, 159, 66, 12, 0, 11,
13, 0, 68, 195, 245, 40, 92, 143, 242, 83, 64, 12, 0, 11,
12, 0, 2, 127, 16, 0, 65, 205, 0, 11,
12, 0, 11, 6, 0, 32, 0, 13, 0, 11,
11, 0, 65, 50, 32, 0, 13, 0, 26, 65, 51, 11,
9, 0, 32, 0, 14, 2, 0, 0, 0, 11,
12, 0, 65, 50, 32, 0, 14, 1, 0, 0, 65, 51, 11,
12, 0, 2, 64, 32, 0, 14, 2, 0, 1, 0, 11,
11, 19, 0, 2, 127, 65, 50, 32, 0, 14, 2, 0, 1, 0, 65, 51, 11,
65, 2, 106, 11, 6, 1, 1, 127, 32, 0, 11, 6, 1, 1, 126, 32, 0, 11, 6, 1, 1, 125, 32, 0, 11, 6, 1, 1, 124, 32, 0, 11
]
+/
