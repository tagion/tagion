module tagion.wasm.WasmExpr;

import std.bitmanip : nativeToLittleEndian;
import std.format;
import std.outbuffer;
import std.traits : ForeachType, Unqual, isArray, isIntegral;
import tagion.wasm.WasmBase;
import tagion.utils.LEB128;

@safe:
struct WasmExpr {
    OutBuffer bout;
    @disable this();
    this(OutBuffer bout) pure nothrow {
        this.bout = bout;
    }

    ref WasmExpr opCall(Args...)(const IR ir, Args args) {
        auto instr = instrTable.lookup(ir);
        bout.write(cast(ubyte) ir);
        with (IRType) {
            final switch (instr.irtype) {
            case PREFIX:
            case CODE:
            case CODE_TYPE:
            case OP_STACK:
            case RETURN:
                assert(Args.length == 0,
                        format("Instruction %s should have no arguments", instr.name));
                break;
            case CODE_EXTEND:
                assert(Args.length == 1,
                        format("Instruction %s should have one extended opcode arguments", instr.name));
                static if ((Args.length == 1) && isIntegral!(Args[0])) {
                    bout.write(encode(args[0]));
                }
                break;
            case BRANCH:
                if (ir is IR.BR_TABLE) {
                    scope uint[] table;
                    static foreach (i, a; args) {
                        {
                            enum OK = is(Args[i] : const(uint)) || is(Args[i] : const(uint[]));
                            assert(OK, format("Argument %d must be integer or uint[] of integer not %s",
                                    i, Args[i].stringof));
                            static if (OK) {
                                table ~= a;
                            }
                        }
                    }
                    check(table.length >= 1, format("Too few arguments for %s instruction", instr.name));
                    bout.write(encode(table.length - 1));
                    foreach (t; table) {
                        bout.write(encode(t));
                    }
                    break;
                }
                goto case;
            case CALL, LOCAL, GLOBAL:
                assert(Args.length == 1,
                        format("Instruction %s only one argument expected", instr.name));
                goto case;
            case BLOCK_CONDITIONAL:
            case BLOCK:
            case BLOCK_ELSE:
                static if (Args.length == 1) {
                    assert(isIntegral!(Args[0]), format("Args idx must be an integer for %s not %s",
                            instr.name, Args[0].stringof));
                    static if (isIntegral!(Args[0])) {
                        bout.write(encode(args[0]));
                    }
                }
                break;
            case CALL_INDIRECT:
                assert(Args.length == 2, format("Instruction %s one argument", instr.name));
                static if (Args.length == 2) {
                    static assert(isIntegral!(Args[0]) && isIntegral!(Args[1]),
                            format("The %s must be table-idx and type-idx not %s and %s", instr.name,
                            Args[0].stringof, Args[1].stringof));
                    static if (isIntegral!(Args[0]) && isIntegral!(Args[1])) {
                        bout.write(encode(args[0]));
                        bout.write(encode(args[1]));
                    }
                }
                break;
            case LOAD:
            case STORE:
                assert(Args.length == 2, format("Instruction %s two arguments", instr.name));
                static if (Args.length == 2) {
                    assert(isIntegral!(Args[0]),
                            format("The funcidx must be an integer for %s", instr.name));
                    assert(isIntegral!(Args[1]),
                            format("The funcidx must be an integer for %s", instr.name));
                    static if (isIntegral!(Args[0]) && isIntegral!(Args[1])) {
                        bout.write(encode(args[0]));
                        bout.write(encode(args[1]));
                    }
                }
                break;
            case MEMORY:
                assert(Args.length == 0,
                        format("Instruction %s should have no arguments", instr.name));
                bout.write(cast(ubyte)(0x00));
                break;
            case CONST:
                assert(Args.length == 1, format("Instruction %s one argument", instr.name));
                static if (Args.length == 1) {
                    alias BaseArg0 = Unqual!(Args[0]);
                    with (IR) {
                        switch (ir) {
                        case I32_CONST:
                            assert(is(BaseArg0 == int) || is(BaseArg0 == uint),
                                    format("Bad type %s for the %s instruction",
                                    BaseArg0.stringof, instr.name));
                            static if (is(BaseArg0 == int) || is(BaseArg0 == uint)) {
                                bout.write(encode(args[0]));
                            }
                            break;
                        case I64_CONST:
                            assert(isIntegral!(BaseArg0), format("Bad type %s for the %s instruction",
                                    BaseArg0.stringof, instr.name));
                            static if (isIntegral!(BaseArg0)) {
                                bout.write(encode(args[0]));
                            }
                            break;
                        case F32_CONST:
                            assert(is(BaseArg0 : float), format("Bad type %s for the %s instruction",
                                    Args[0].stringof, instr.name));
                            static if (is(BaseArg0 : float)) {
                                float x = args[0];
                                bout.write(nativeToLittleEndian(x));
                            }
                            break;
                        case F64_CONST:
                            assert(is(BaseArg0 : double), format("Bad type %s for the %s instruction",
                                    Args[0].stringof, instr.name));
                            static if (is(BaseArg0 : double)) {
                                double x = args[0];
                                bout.write(nativeToLittleEndian(x));
                            }
                            break;
                        default:
                            assert(0, format("Bad const instruction %s", instr.name));
                        }
                    }
                }
                break;
            case END:
                assert(Args.length == 0,
                        format("Instruction %s should have no arguments", instr.name));
                break;
            case ILLEGAL:
                assert(0, format("Illegal opcode %02X", ir));
                break;
            case REF:
                switch (ir) {
                case IR.REF_NULL:
                    assert(Args.length == 1, "Type expected");
                    static if ((Args.length == 1) && is(Args[0] : const(Types))) {
                                import tagion.basic.Debug;
                                __write("%s args %s", Args[0].stringof, args[0]);
                        bout.write(cast(ubyte) args[0]);
                    }
                    break;
                default:
                    assert(ir is IR.REF_NULL, "Ref instructions not supported yet");
                }
                break;
            case SYMBOL:
                assert(0, "Symbol opcode and it does not have an equivalent opcode");
            }
        }
        return this;
    }

    void append(const WasmExpr e) pure nothrow {
        bout.write(e.bout.toBytes);
    }

    bool opEquals(const WasmExpr e) const pure nothrow @nogc {
        return bout is e.bout;
    }

    immutable(ubyte[]) serialize() const pure nothrow {
        return bout.toBytes.idup;
    }
}
