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
    protected {
        Output output;
        Wdisasm dasm;
        string indent;
    }

    this(Wdisasm dasm, Output output) { //static if (isOutputRange!Ouput) {
        this.output=output;
        this.dasm=dasm;
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
        output.writefln("Code types length=%s", _code.length);
        foreach(c; _code[]) {
            output.writefln("c.size=%d c.data.length=%d c.locals=%s c[]=%s", c.size, c.data.length, c.locals, c[]);
        }
    }

    void data_sec(ref scope const(Module) mod) {
    }


    Output serialize(string spacer=null) {
        output.writeln("(module");
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
