module wavm.WasmExpr;

import std.bitmanip : nativeToLittleEndian;
import std.traits : Unqual, isArray, isIntegral, ForeachType;
import std.outbuffer;
import std.format;

import wavm.WasmBase;
import wavm.LEB128;

struct WasmExpr {
    protected OutBuffer bout;
    @disable this();
    this(OutBuffer bout) {
        this.bout=bout;
    }

    ref WasmExpr opCall(Args...)(const IR ir, Args args) {
        immutable instr=instrTable[ir];
        bout.write(cast(ubyte)ir);
        immutable irtype=instr.irtype;
        with(IRType) {
            final switch(irtype) {
            case CODE:
                assert(Args.length == 0, format("Instruction %s should have no arguments", instr.name));
                // No args
                break;
            case BLOCK, BRANCH, CALL, LOCAL, GLOBAL:
                assert(Args.length == 1, format("Instruction %s only one argument expected", instr.name));
                static if (Args.length == 1) {
                    assert(isIntegral!(Args[0]), format("Args idx must be an integer for %s not %s",
                            instr.name, Args[0].stringof));
                    bout.write(encode(args[0]));
                }
                break;
            case BRANCH_TABLE:
                scope uint[] table;
                static foreach(i, a; args) {
                    alias BaseT=Unqual!(Args[i]);
                    static if (is(isArray!BaseT)) {
                        assert(isIntegral!(ForeachType!BaseT),
                            format("Type %s for as argument for instruction %s is not allowed",
                                Args[i], instr.name));
                        foreach(e; args[i]) {
                            table~=e;
                        }

                    }
                    else {
                        assert(isIntegral!(BaseT),
                            format("Bad type %s of argument %d for instruction %s",
                                BaseT.stringof, i, instr.name));
                            table~=a;
                    }
                }
                check(table.length > 2, format("Too few arguments for %s instruction", instr.name));
                bout.write(encode(table.length-1));
                foreach(t; table) {
                    bout.write(encode(t));
                }
                break;
            case CALL_INDIRECT:
                assert(Args.length == 1, format("Instruction %s one argument", instr.name));
                static if (Args.length == 1) {
                    assert(isIntegral!(Args[0]), format("The funcidx must be an integer for %s", instr.name));
                    bout.write(encode(args[0]));
                    bout.write(cast(ubyte)(0x00));
                }
                break;
            case MEMORY:
                assert(Args.length == 2, format("Instruction %s two arguments", instr.name));
                static if (Args.length == 2) {
                    assert(isIntegral!(Args[0]), format("The funcidx must be an integer for %s", instr.name));
                    assert(isIntegral!(Args[1]), format("The funcidx must be an integer for %s", instr.name));
                    bout.write(encode(args[0]));
                    bout.write(encode(args[1]));
                }
                break;
            case MEMOP:
                assert(Args.length == 0, format("Instruction %s should have no arguments", instr.name));
                bout.write(cast(ubyte)(0x00));
                break;
            case CONST:
                assert(Args.length == 1, format("Instruction %s one argument", instr.name));
                static if (Args.length == 1) {
                alias BaseArg0=Unqual!(Args[0]);
                with(IR) {
                    switch (ir) {
                    case I32_CONST:
                        assert(is(BaseArg0==int) || is(BaseArg0==uint),
                            format("Bad type %s for the %s instruction",
                                BaseArg0.stringof, instr.name));
                        bout.write(encode(args[0]));
                        break;
                    case I64_CONST:
                        assert(isIntegral!(BaseArg0),
                            format("Bad type %s for the %s instruction",
                                BaseArg0 .stringof, instr.name));
                        bout.write(encode(args[0]));
                        break;
                    case F32_CONST:
                        assert(is(BaseArg0:float),
                            format("Bad type %s for the %s instruction",
                                Args[0].stringof, instr.name));
                        float x=args[0];
                        bout.write(nativeToLittleEndian(x));
                        break;
                    case F64_CONST:
                        assert(is(BaseArg0:double), format("Bad type %s for the %s instruction",
                                Args[0].stringof, instr.name));
                        double x=args[0];
                        bout.write(nativeToLittleEndian(x));
                        break;
                    default:
                        assert(0, format("Bad const instruction %s", instr.name));
                    }
                }
                }
                break;
            case END:
                assert(Args.length == 0, format("Instruction %s should have no arguments", instr.name));
            }
        }
        return this;
    }
}
