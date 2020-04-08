module wavm.Disassemble;

import std.format;
import std.stdio;
import std.traits : EnumMembers;
import std.typecons : Tuple;
import std.uni : toLower;
import std.conv : to;
import std.range.primitives : isOutputRange;

import wavm.Wasm;

struct Disassemble {
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
        const(WasmSection.Custom)[],  "customs",
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

    void opCall(scope ModuleIterator dg) {
        scope Module mod;
        Wasm.Section previous_sec;
        foreach(a; wasm[]) {
            with(Wasm.Section) {
                if ((a.section !is CUSTOM) && (simple_error(previous_sec < a.section, "Bad order"))) {
                    previous_sec=a.section;
                    final switch(a.section) {
                        foreach(E; EnumMembers!(Wasm.Section)) {
                            static if (E is CUSTOM) {
                            case CUSTOM:
                                mod.customs~=a.sec!CUSTOM;
                                break;
                            }
                            else {
                                case E:
                                    const sec=a.sec!E;
                                    mod[E]=&sec;
                                    break;
                            }
                        }
                    }
                }
            }
            dg(a.section, mod);
        }
    }
}


void wast(Range)(Disassembler dasm,  Range output) if (isOutputRange!Range) {
    dasm((const Section sec, ref scope const(Disassembler.Module) mod) => {
            with(Wasm.Section) {
                final switch(a.sec) {
                    foreach(E; EnumMembers!(Wasm.Section)) {
                    case E:
                    writelfn("sec=%s", mod[E]);
                    break;
                    }
                }
            }
        });
}
