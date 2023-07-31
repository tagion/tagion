module tagion.wasm.WasmBase;

import std.traits : EnumMembers, Unqual, isAssociativeArray, ForeachType, ConstOf, isFunctionPointer, getUDAs;
import std.meta : AliasSeq;
import std.typecons : Tuple;
import std.format;
import std.uni : toLower;
import std.conv : to, emplace;
import std.range.primitives : isInputRange;
import std.bitmanip : binread = read, binwrite = write, binpeek = peek, Endian;

import std.exception : assumeWontThrow, assumeUnique;

import std.stdio;
import tagion.wasm.WasmException;

import LEB128 = tagion.utils.LEB128;

enum VerboseMode {
    NONE,
    STANDARD
}

@safe struct Verbose {
    VerboseMode mode;
    string indent;
    File fout;
    enum INDENT = "  ";
    enum WIDTH = 16;

    void opCall(Args...)(string fmt, lazy Args args) {
        if (mode !is VerboseMode.NONE) {
            fout.write(indent);
            fout.writefln(fmt, args);
        }
    }

    void print(Args...)(string fmt, lazy Args args) {
        if (mode !is VerboseMode.NONE) {
            fout.writef(fmt, args);
        }
    }

    void println(Args...)(string fmt, lazy Args args) {
        if (mode !is VerboseMode.NONE) {
            fout.writefln(fmt, args);
        }
    }

    void down() nothrow {
        if (mode !is VerboseMode.NONE) {
            indent ~= INDENT;
        }
    }

    void up() nothrow {
        if (mode !is VerboseMode.NONE) {
            if (indent.length >= INDENT.length) {
                indent.length -= INDENT.length;
            }
        }
    }

    void hex(const size_t index, const(ubyte[]) data) {
        if (mode !is VerboseMode.NONE) {
            size_t _index = index;
            foreach (const i, d; data) {
                if (i % WIDTH is 0) {
                    if (i !is 0) {
                        fout.writeln("");
                    }
                    fout.writef("%s%06X", indent, _index);
                }
                fout.writef(" %02X", d);
                _index++;
            }
            fout.writeln("");
        }
    }

    void ln() {
        if (mode !is VerboseMode.NONE) {
            fout.writeln("");
        }
    }

}

static Verbose verbose;

static this() {
    verbose.fout = stdout;
}

enum Section : ubyte {
    CUSTOM = 0,
    TYPE = 1,
    IMPORT = 2,
    FUNCTION = 3,
    TABLE = 4,
    MEMORY = 5,
    GLOBAL = 6,
    EXPORT = 7,
    START = 8,
    ELEMENT = 9,
    CODE = 10,
    DATA = 11,
}

enum IRType {
    CODE, /// Simple instruction with no argument
    BLOCK, /// Block instruction
    //    BLOCK_IF,      /// Block for [IF] ELSE END
    //   BLOCK_ELSE,    /// Block for IF [ELSE] END
    BRANCH, /// Branch jump instruction
    BRANCH_IF, /// Conditional branch jump instruction
    BRANCH_TABLE, /// Branch table jump instruction
    CALL, /// Subroutine call
    CALL_INDIRECT, /// Indirect subroutine call
    LOCAL, /// Local register storage instruction
    GLOBAL, /// Global register storage instruction
    MEMORY, /// Memory instruction
    MEMOP, /// Memory management instruction
    CONST, /// Constant argument
    END, /// Block end instruction
    PREFIX, /// Prefix for two byte extension
    SYMBOL, /// This is extra instruction which does not have an equivalent wasm opcode
}

struct Instr {
    string name; /// Instruction name
    string wast; /// Wast name 
    uint cost;
    IRType irtype;
    uint pops; // Number of pops from the stack
    uint push; // Number of valus pushed
    bool extend; // Extended
}

enum ubyte[] magic = [0x00, 0x61, 0x73, 0x6D];
enum ubyte[] wasm_version = [0x01, 0x00, 0x00, 0x00];
enum IR : ubyte {
    // dfmt off
        @Instr("unreachable", "unreachable", 1, IRType.CODE)               UNREACHABLE         = 0x00, ///  unreachable
        @Instr("nop", "nop", 1, IRType.CODE)                       NOP                 = 0x01, ///  nop
        @Instr("block", "block", 0, IRType.BLOCK)                    BLOCK               = 0x02, ///  block rt:blocktype (in:instr) * end
        @Instr("loop", "loop", 0, IRType.BLOCK)                     LOOP                = 0x03, ///  loop rt:blocktype (in:instr) * end
        @Instr("if", "if", 1, IRType.BLOCK, 1)                    IF                  = 0x04, /++     if rt:blocktype (in:instr) *rt in * else ? end
                                                                                        if rt:blocktype (in1:instr) *rt in * 1 else (in2:instr) * end
                                                                                        +/
        @Instr("else", "else", 0, IRType.END)                       ELSE                = 0x05, ///  else
        @Instr("end", "end", 0, IRType.END)                        END                 = 0x0B, ///  end
        @Instr("br", "br", 1, IRType.BRANCH, 1)                      BR                  = 0x0C, ///  br l:labelidx
        @Instr("br_if", "br_if", 1, IRType.BRANCH_IF, 1)                BR_IF               = 0x0D, ///  br_if l:labelidx
        @Instr("br_table", "br_table", 1, IRType.BRANCH_TABLE, 1)       BR_TABLE            = 0x0E, ///  br_table l:vec(labelidx) * lN:labelidx
        @Instr("return", "return", 1, IRType.CODE, 1)                    RETURN              = 0x0F, ///  return
        @Instr("call", "call", 1, IRType.CALL)                      CALL                = 0x10, ///  call x:funcidx
        @Instr("call_indirect", "call_indirect", 1, IRType.CALL_INDIRECT, 1) CALL_INDIRECT       = 0x11, ///  call_indirect x:typeidx 0x00
        @Instr("drop", "drop", 1, IRType.CODE, 1)                   DROP                = 0x1A, ///  drop
        @Instr("select", "select", 1, IRType.CODE, 3, 1)              SELECT              = 0x1B, ///  select
        @Instr("local.get", "get_local", 1, IRType.LOCAL, 0, 1)          LOCAL_GET           = 0x20, ///  local.get x:localidx
        @Instr("local.set", "set_local", 1, IRType.LOCAL, 1)             LOCAL_SET           = 0x21, ///  local.set x:localidx
        @Instr("local.tee", "tee_local", 1, IRType.LOCAL, 1, 1)          LOCAL_TEE           = 0x22, ///  local.tee x:localidx
        @Instr("global.get", "get_global", 1, IRType.GLOBAL, 1, 0)        GLOBAL_GET          = 0x23, ///  global.get x:globalidx
        @Instr("global.set", "set_global", 1, IRType.GLOBAL, 0, 1)        GLOBAL_SET          = 0x24, ///  global.set x:globalidx

        @Instr("i32.load", "i32.load", 2, IRType.MEMORY, 1, 1)          I32_LOAD            = 0x28, ///  i32.load     m:memarg
        @Instr("i64.load", "i64.load", 2, IRType.MEMORY, 1, 1)          I64_LOAD            = 0x29, ///  i64.load     m:memarg
        @Instr("f32.load", "f32.load", 2, IRType.MEMORY, 1, 1)          F32_LOAD            = 0x2A, ///  f32.load     m:memarg
        @Instr("f64.load", "f64.load", 2, IRType.MEMORY, 1, 1)          F64_LOAD            = 0x2B, ///  f64.load     m:memarg
        @Instr("i32.load8_s", "i32.load8_s", 2, IRType.MEMORY, 1, 1)       I32_LOAD8_S         = 0x2C, ///  i32.load8_s  m:memarg
        @Instr("i32.load8_u", "i32.load8_u", 2, IRType.MEMORY, 1, 1)       I32_LOAD8_U         = 0x2D, ///  i32.load8_u  m:memarg
        @Instr("i32.load16_s", "i32.load16_s", 2, IRType.MEMORY, 1, 1)      I32_LOAD16_S        = 0x2E, ///  i32.load16_s m:memarg
        @Instr("i32.load16_u", "i32.load16_u", 2, IRType.MEMORY, 1, 1)      I32_LOAD16_U        = 0x2F, ///  i32.load16_u m:memarg
        @Instr("i64.load8_s", "i64.load8_s", 2, IRType.MEMORY, 1, 1)       I64_LOAD8_S         = 0x30, ///  i64.load8_s  m:memarg
        @Instr("i64.load8_u", "i64.load8_u", 2, IRType.MEMORY, 1, 1)       I64_LOAD8_U         = 0x31, ///  i64.load8_u  m:memarg
        @Instr("i64.load16_s", "i64.load16_s", 2, IRType.MEMORY, 1, 1)      I64_LOAD16_S        = 0x32, ///  i64.load16_s m:memarg
        @Instr("i64.load16_u", "i64.load16_u", 2, IRType.MEMORY, 1, 1)      I64_LOAD16_U        = 0x33, ///  i64.load16_u m:memarg
        @Instr("i64.load32_s", "i64.load32_s", 2, IRType.MEMORY, 1, 1)      I64_LOAD32_S        = 0x34, ///  i64.load32_s m:memarg
        @Instr("i64.load32_u", "i64.load32_u", 2, IRType.MEMORY, 1, 1)      I64_LOAD32_U        = 0x35, ///  i64.load32_u m:memarg
        @Instr("i32.store", "i32.store", 2, IRType.MEMORY, 2)            I32_STORE           = 0x36, ///  i32.store    m:memarg
        @Instr("i64.store", "i64.store", 2, IRType.MEMORY, 2)            I64_STORE           = 0x37, ///  i64.store    m:memarg
        @Instr("f32.store", "f32.store", 2, IRType.MEMORY, 2)            F32_STORE           = 0x38, ///  f32.store    m:memarg
        @Instr("f64.store", "f64.store", 2, IRType.MEMORY, 2)            F64_STORE           = 0x39, ///  f64.store    m:memarg
        @Instr("i32.store8", "i32.store8", 2, IRType.MEMORY, 2)           I32_STORE8          = 0x3A, ///  i32.store8   m:memarg
        @Instr("i32.store16", "i32.store16", 2, IRType.MEMORY, 2)          I32_STORE16         = 0x3B, ///  i32.store16  m:memarg
        @Instr("i64.store8", "i64.store8", 2, IRType.MEMORY, 2)           I64_STORE8          = 0x3C, ///  i64.store8   m:memarg
        @Instr("i64.store16", "i64.store16", 2, IRType.MEMORY, 2)          I64_STORE16         = 0x3D, ///  i64.store16  m:memarg
        @Instr("i64.store32", "i64.store32", 2, IRType.MEMORY, 2)          I64_STORE32         = 0x3E, ///  i64.store32  m:memarg
        @Instr("memory.size", "memory_size", 7, IRType.MEMOP, 0, 2)        MEMORY_SIZE         = 0x3F, ///  memory.size  0x00
        @Instr("memory.grow", "grow_memory", 7, IRType.MEMOP, 1, 2)        MEMORY_GROW         = 0x40, ///  memory.grow  0x00

        @Instr("i32.const", "i32.const", 1, IRType.CONST, 0, 1)          I32_CONST           = 0x41, ///  i32.const n:i32
        @Instr("i64.const", "i64.const", 1, IRType.CONST, 0, 1)          I64_CONST           = 0x42, ///  i64.const n:i64
        @Instr("f32.const", "f32.const", 1, IRType.CONST, 0, 1)          F32_CONST           = 0x43, ///  f32.const z:f32
        @Instr("f64.const", "f64.const", 1, IRType.CONST, 0, 1)          F64_CONST           = 0x44, ///  f64.const z:f64

        @Instr("i32.eqz", "i32.eqz", 1, IRType.CODE, 1)                I32_EQZ             = 0x45, ///  i32.eqz
        @Instr("i32.eq", "i32.eq", 1, IRType.CODE, 2, 1)                 I32_EQ              = 0x46, ///  i32.eq
        @Instr("i32.ne", "i32.ne", 1, IRType.CODE, 2, 1)                 I32_NE              = 0x47, ///  i32.ne
        @Instr("i32.lt_s", "i32.lt_s", 1, IRType.CODE, 2, 1)            I32_LT_S            = 0x48, ///  i32.lt_s
        @Instr("i32.lt_u", "i32.lt_u", 1, IRType.CODE, 2, 1)            I32_LT_U            = 0x49, ///  i32.lt_u
        @Instr("i32.gt_s", "i32.gt_s", 1, IRType.CODE, 2, 1)            I32_GT_S            = 0x4A, ///  i32.gt_s
        @Instr("i32.gt_u", "i32.gt_u", 1, IRType.CODE, 2, 1)            I32_GT_U            = 0x4B, ///  i32.gt_u
        @Instr("i32.le_s", "i32.le_s", 1, IRType.CODE, 2, 1)            I32_LE_S            = 0x4C, ///  i32.le_s
        @Instr("i32.le_u", "i32.le_u", 1, IRType.CODE, 2, 1)            I32_LE_U            = 0x4D, ///  i32.le_u
        @Instr("i32.ge_s", "i32.ge_s", 1, IRType.CODE, 2, 1)            I32_GE_S            = 0x4E, ///  i32.ge_s
        @Instr("i32.ge_u", "i32.ge_u", 1, IRType.CODE, 2, 1)            I32_GE_U            = 0x4F, ///  i32.ge_u

        @Instr("i64.eqz", "i64.eqz", 1, IRType.CODE, 2, 1)             I64_EQZ             = 0x50, ///  i64.eqz
        @Instr("i64.eq", "i64.eq", 1, IRType.CODE, 2, 1)              I64_EQ              = 0x51, ///  i64.eq
        @Instr("i64.ne", "i64.ne", 1, IRType.CODE, 2, 1)              I64_NE              = 0x52, ///  i64.ne
        @Instr("i64.lt_s", "i64.lt_s", 1, IRType.CODE, 2, 1)                  I64_LT_S            = 0x53, ///  i64.lt_s

        @Instr("i64.lt_u", "i64.lt_u", 1, IRType.CODE, 2, 1)            I64_LT_U            = 0x54, ///  i64.lt_u
        @Instr("i64.gt_s", "i64.gt_s", 1, IRType.CODE, 2, 1)            I64_GT_S            = 0x55, ///  i64.gt_s
        @Instr("i64.gt_u", "i64.gt_u", 1, IRType.CODE, 2, 1)            I64_GT_U            = 0x56, ///  i64.gt_u
        @Instr("i64.le_s", "i64.le_s", 1, IRType.CODE, 2, 1)            I64_LE_S            = 0x57, ///  i64.le_s
        @Instr("i64.le_u", "i64.le_u", 1, IRType.CODE, 2, 1)            I64_LE_U            = 0x58, ///  i64.le_u
        @Instr("i64.ge_s", "i64.ge_s", 1, IRType.CODE, 2, 1)            I64_GE_S            = 0x59, ///  i64.ge_s
        @Instr("i64.ge_u", "i64.ge_u", 1, IRType.CODE, 2, 1)            I64_GE_U            = 0x5A, ///  i64.ge_u

        @Instr("f32.eq", "f32.eq", 1, IRType.CODE, 2, 1)                 F32_EQ              = 0x5B, ///  f32.eq
        @Instr("f32.ne", "f32.ne", 1, IRType.CODE, 2, 1)                 F32_NE              = 0x5C, ///  f32.ne
        @Instr("f32.lt", "f32.lt", 1, IRType.CODE, 2, 1)                 F32_LT              = 0x5D, ///  f32.lt
        @Instr("f32.gt", "f32.gt", 1, IRType.CODE, 2, 1)                 F32_GT              = 0x5E, ///  f32.gt
        @Instr("f32.le", "f32.le", 1, IRType.CODE, 2, 1)                 F32_LE              = 0x5F, ///  f32.le
        @Instr("f32.ge", "f32.ge", 1, IRType.CODE, 2, 1)                 F32_GE              = 0x60, ///  f32.ge

        @Instr("f64.eq", "f64.eq", 1, IRType.CODE, 2, 1)                 F64_EQ              = 0x61, ///  f64.eq
        @Instr("f64.ne", "f64.ne", 1, IRType.CODE, 2, 1)                 F64_NE              = 0x62, ///  f64.ne
        @Instr("f64.lt", "f64.lt", 1, IRType.CODE, 2, 1)                 F64_LT              = 0x63, ///  f64.lt
        @Instr("f64.gt", "f64.gt", 1, IRType.CODE, 2, 1)                 F64_GT              = 0x64, ///  f64.gt
        @Instr("f64.le", "f64.le", 1, IRType.CODE, 2, 1)                 F64_LE              = 0x65, ///  f64.le
        @Instr("f64.ge", "f64.ge", 1, IRType.CODE, 2, 1)                 F64_GE              = 0x66, ///  f64.ge

            // instructions
        @Instr("i32.clz", "i32.clz", 1, IRType.CODE, 1, 1)             I32_CLZ             = 0x67, ///  i32.clz
        @Instr("i32.ctz", "i32.ctz", 1, IRType.CODE, 1, 1)             I32_CTZ             = 0x68, ///  i32.ctz
        @Instr("i32.popcnt", "i32.popcnt", 1, IRType.CODE, 1, 1)          I32_POPCNT          = 0x69, ///  i32.popcnt
        @Instr("i32.add", "i32.add", 1, IRType.CODE, 2, 1)             I32_ADD             = 0x6A, ///  i32.add
        @Instr("i32.sub", "i32.sub", 1, IRType.CODE, 2, 1)             I32_SUB             = 0x6B, ///  i32.sub
        @Instr("i32.mul", "i32.mul", 1, IRType.CODE, 2, 1)             I32_MUL             = 0x6C, ///  i32.mul
        @Instr("i32.div_s", "i32.div_s", 1, IRType.CODE, 2, 1)           I32_DIV_S           = 0x6D, ///  i32.div_s
        @Instr("i32.div_u", "i32.div_u", 1, IRType.CODE, 2, 1)           I32_DIV_U           = 0x6E, ///  i32.div_u
        @Instr("i32.rem_s", "i32.rem_s", 1, IRType.CODE, 2, 1)           I32_REM_S           = 0x6F, ///  i32.rem_s
        @Instr("i32.rem_u", "i32.rem_u", 1, IRType.CODE, 2, 1)           I32_REM_U           = 0x70, ///  i32.rem_u
        @Instr("i32.and", "i32.and", 1, IRType.CODE, 2, 1)             I32_AND             = 0x71, ///  i32.and
        @Instr("i32.or", "i32.or", 1, IRType.CODE, 2, 1)              I32_OR              = 0x72, ///  i32.or
        @Instr("i32.xor", "i32.xor", 1, IRType.CODE, 2, 1)             I32_XOR             = 0x73, ///  i32.xor
        @Instr("i32.shl", "i32.shl", 1, IRType.CODE, 2, 1)             I32_SHL             = 0x74, ///  i32.shl
        @Instr("i32.shr_s", "i32.shr_s", 1, IRType.CODE, 2, 1)           I32_SHR_S           = 0x75, ///  i32.shr_s
        @Instr("i32.shr_u", "i32.shr_u", 1, IRType.CODE, 2, 1)           I32_SHR_U           = 0x76, ///  i32.shr_u
        @Instr("i32.rotl", "i32.rotl", 1, IRType.CODE, 2, 1)            I32_ROTL            = 0x77, ///  i32.rotl
        @Instr("i32.rotr", "i32.rotr", 1, IRType.CODE, 2, 1)            I32_ROTR            = 0x78, ///  i32.rotr

        @Instr("i64.clz", "i64.clz", 1, IRType.CODE, 1, 1)             I64_CLZ             = 0x79, ///  i64.clz
        @Instr("i64.ctz", "i64.ctz", 1, IRType.CODE, 1, 1)             I64_CTZ             = 0x7A, ///  i64.ctz
        @Instr("i64.popcnt", "i64.popcnt", 1, IRType.CODE, 1, 1)          I64_POPCNT          = 0x7B, ///  i64.popcnt
        @Instr("i64.add", "i64.add", 1, IRType.CODE, 2, 1)             I64_ADD             = 0x7C, ///  i64.add
        @Instr("i64.sub", "i64.sub", 1, IRType.CODE, 2, 1)             I64_SUB             = 0x7D, ///  i64.sub
        @Instr("i64.mul", "i64.mul", 1, IRType.CODE, 2, 1)             I64_MUL             = 0x7E, ///  i64.mul
        @Instr("i64.div_s", "i64.div_s", 1, IRType.CODE, 2, 1)           I64_DIV_S           = 0x7F, ///  i64.div_s
        @Instr("i64.div_u", "i64.div_u", 1, IRType.CODE, 2, 1)           I64_DIV_U           = 0x80, ///  i64.div_u
        @Instr("i64.rem_s", "i64.rem_s", 1, IRType.CODE, 2, 1)           I64_REM_S           = 0x81, ///  i64.rem_s
        @Instr("i64.rem_u", "i64.rem_u", 1, IRType.CODE, 2, 1)           I64_REM_U           = 0x82, ///  i64.rem_u
        @Instr("i64.and", "i64.and", 1, IRType.CODE, 2, 1)             I64_AND             = 0x83, ///  i64.and
        @Instr("i64.or", "i64.or", 1, IRType.CODE, 2, 1)              I64_OR              = 0x84, ///  i64.or
        @Instr("i64.xor", "i64.xor", 1, IRType.CODE, 2, 1)             I64_XOR             = 0x85, ///  i64.xor
        @Instr("i64.shl", "i64.shl", 1, IRType.CODE, 2, 1)             I64_SHL             = 0x86, ///  i64.shl
        @Instr("i64.shr_s", "i64.shr_s", 1, IRType.CODE, 2, 1)           I64_SHR_S           = 0x87, ///  i64.shr_s
        @Instr("i64.shr_u", "i64.shr_u", 1, IRType.CODE, 2, 1)           I64_SHR_U           = 0x88, ///  i64.shr_u
        @Instr("i64.rotl", "i64.rotl", 1, IRType.CODE, 2, 1)            I64_ROTL            = 0x89, ///  i64.rotl
        @Instr("i64.rotr", "i64.rotr", 1, IRType.CODE, 2, 1)            I64_ROTR            = 0x8A, ///  i64.rotr

        @Instr("f32.abs", "f32.abs", 1, IRType.CODE, 1, 1)             F32_ABS             = 0x8B, ///  f32.abs
        @Instr("f32.neg", "f32.neg", 1, IRType.CODE, 1, 1)             F32_NEG             = 0x8C, ///  f32.neg
        @Instr("f32.ceil", "f32.ceil", 1, IRType.CODE, 1, 1)            F32_CEIL            = 0x8D, ///  f32.ceil
        @Instr("f32.floor", "f32.floor", 1, IRType.CODE, 1, 1)           F32_FLOOR           = 0x8E, ///  f32.floor
        @Instr("f32.trunc", "f32.trunc", 1, IRType.CODE, 1, 1)           F32_TRUNC           = 0x8F, ///  f32.trunc
        @Instr("f32.nearest", "f32.nearest", 1, IRType.CODE, 1, 1)         F32_NEAREST         = 0x90, ///  f32.nearest
        @Instr("f32.sqrt", "f32.sqrt", 3, IRType.CODE, 1, 1)            F32_SQRT            = 0x91, ///  f32.sqrt
        @Instr("f32.add", "f32.add", 3, IRType.CODE, 2, 1)             F32_ADD             = 0x92, ///  f32.add
        @Instr("f32.sub", "f32.sub", 3, IRType.CODE, 2, 1)             F32_SUB             = 0x93, ///  f32.sub
        @Instr("f32.mul", "f32.mul", 3, IRType.CODE, 2, 1)             F32_MUL             = 0x94, ///  f32.mul
        @Instr("f32.div", "f32.div", 3, IRType.CODE, 2, 1)             F32_DIV             = 0x95, ///  f32.div
        @Instr("f32.min", "f32.min", 1, IRType.CODE, 2, 1)             F32_MIN             = 0x96, ///  f32.min
        @Instr("f32.max", "f32.max", 1, IRType.CODE, 2, 1)             F32_MAX             = 0x97, ///  f32.max
        @Instr("f32.copysign", "f32.copysign", 1, IRType.CODE, 2, 1)        F32_COPYSIGN        = 0x98, ///  f32.copysign

        @Instr("f64.abs", "f64.abs", 1, IRType.CODE, 1, 1)             F64_ABS             = 0x99, ///  f64.abs
        @Instr("f64.neg", "f64.neg", 1, IRType.CODE, 1, 1)             F64_NEG             = 0x9A, ///  f64.neg
        @Instr("f64.ceil", "f64.ceil", 1, IRType.CODE, 1, 1)            F64_CEIL            = 0x9B, ///  f64.ceil
        @Instr("f64.floor", "f64.floor", 1, IRType.CODE, 1, 1)           F64_FLOOR           = 0x9C, ///  f64.floor
        @Instr("f64.trunc", "f64.trunc", 1, IRType.CODE, 1, 1)           F64_TRUNC           = 0x9D, ///  f64.trunc
        @Instr("f64.nearest", "f64.nearest", 1, IRType.CODE, 1, 1)         F64_NEAREST         = 0x9E, ///  f64.nearest
        @Instr("f64.sqrt", "f64.sqrt", 3, IRType.CODE, 1, 1)            F64_SQRT            = 0x9F, ///  f64.sqrt
        @Instr("f64.add", "f64.add", 3, IRType.CODE, 2, 1)             F64_ADD             = 0xA0, ///  f64.add
        @Instr("f64.sub", "f64.sub", 3, IRType.CODE, 2, 1)             F64_SUB             = 0xA1, ///  f64.sub
        @Instr("f64.mul", "f64.mul", 3, IRType.CODE, 2, 1)             F64_MUL             = 0xA2, ///  f64.mul
        @Instr("f64.div", "f64.div", 3, IRType.CODE, 2, 1)             F64_DIV             = 0xA3, ///  f64.div
        @Instr("f64.min", "f64.min", 1, IRType.CODE, 2, 1)             F64_MIN             = 0xA4, ///  f64.min
        @Instr("f64.max", "f64.max", 1, IRType.CODE, 2, 1)             F64_MAX             = 0xA5, ///  f64.max
        @Instr("f64.copysign", "f64.copysign", 1, IRType.CODE, 2, 1)        F64_COPYSIGN        = 0xA6, ///  f64.copysign

        @Instr("i32.wrap_i64", "i32.wrap/i64", 1, IRType.CODE, 1, 1)        I32_WRAP_I64        = 0xA7, ///  i32.wrap_i64
        @Instr("i32.trunc_f32_s", "i32.trunc_s/f32", 1, IRType.CODE, 1, 1)     I32_TRUNC_F32_S     = 0xA8, ///  i32.trunc_f32_s
        @Instr("i32.trunc_f32_u", "i32.trunc_u/f32", 1, IRType.CODE, 1, 1)     I32_TRUNC_F32_U     = 0xA9, ///  i32.trunc_f32_u
        @Instr("i32.trunc_f64_s", "i32.trunc_s/f64", 1, IRType.CODE, 1, 1)     I32_TRUNC_F64_S     = 0xAA, ///  i32.trunc_f64_s
        @Instr("i32.trunc_f64_u", "i32.trunc_u/f64", 1, IRType.CODE, 1, 1)     I32_TRUNC_F64_U     = 0xAB, ///  i32.trunc_f64_u
        @Instr("i64.extend_i32_s", "i64.extend_s/i32", 1, IRType.CODE, 1, 1)    I64_EXTEND_I32_S    = 0xAC, ///  i64.extend_i32_s
        @Instr("i64.extend_i32_u", "i64.extend_u/i32", 1, IRType.CODE, 1, 1)    I64_EXTEND_I32_U    = 0xAD, ///  i64.extend_i32_u
        @Instr("i32.extend8_s", "i32.extend8_s", 1, IRType.CODE, 1, 1)       I32_EXTEND8_S       = 0xC0, ///  i32.extend8_s
        @Instr("i32.extend16_s", "i32.extend16_s", 1, IRType.CODE, 1, 1)      I32_EXTEND16_S      = 0xC1, ///  i32.extend16_s
        @Instr("i64.extend8_s", "i64.extend8_s", 1, IRType.CODE, 1, 1)       I64_EXTEND8_S       = 0xC2, ///  i64.extend8_s
        @Instr("i64.extend16_s", "i64.extend16_s", 1, IRType.CODE, 1, 1)      I64_EXTEND16_S      = 0xC3, ///  i64.extend16_s
        @Instr("i64.extend32_s", "i64.extend32_s", 1, IRType.CODE, 1, 1)      I64_EXTEND32_S     = 0xC4, ///  i64.extend32_s
        @Instr("i64.trunc_f32_s", "i64.trunc_s/f32", 1, IRType.CODE, 1, 1)     I64_TRUNC_F32_S     = 0xAE, ///  i64.trunc_f32_s
        @Instr("i64.trunc_f32_u", "i64.trunc_u/f32", 1, IRType.CODE, 1, 1)     I64_TRUNC_F32_U     = 0xAF, ///  i64.trunc_f32_u
        @Instr("i64.trunc_f64_s", "i64.trunc_s/f64", 1, IRType.CODE, 1, 1)     I64_TRUNC_F64_S     = 0xB0, ///  i64.trunc_f64_s
        @Instr("i64.trunc_f64_u", "i64.trunc_u/f64", 1, IRType.CODE, 1, 1)     I64_TRUNC_F64_U     = 0xB1, ///  i64.trunc_f64_u
        @Instr("f32.convert_i32_s", "f32.convert_s/i32", 1, IRType.CODE, 1, 1)   F32_CONVERT_I32_S   = 0xB2, ///  f32.convert_i32_s
        @Instr("f32.convert_i32_u", "f32.convert_u/i32", 1, IRType.CODE, 1, 1)   F32_CONVERT_I32_U   = 0xB3, ///  f32.convert_i32_u
        @Instr("f32.convert_i64_s", "f32.convert_s/i64", 1, IRType.CODE, 1, 1)   F32_CONVERT_I64_S   = 0xB4, ///  f32.convert_i64_s
        @Instr("f32.convert_i64_u", "f32.convert_u/i64", 1, IRType.CODE, 1, 1)   F32_CONVERT_I64_U   = 0xB5, ///  f32.convert_i64_u
        @Instr("f32.demote_f64", "f32.demote/f64", 1, IRType.CODE, 1, 1)      F32_DEMOTE_F64      = 0xB6, ///  f32.demote_f64
        @Instr("f64.convert_i32_s", "f64.convert_s/i32", 1, IRType.CODE, 1, 1)   F64_CONVERT_I32_S   = 0xB7, ///  f64.convert_i32_s
        @Instr("f64.convert_i32_u", "f64.convert_u/i32", 1, IRType.CODE, 1, 1)   F64_CONVERT_I32_U   = 0xB8, ///  f64.convert_i32_u
        @Instr("f64.convert_i64_s", "f64.convert_s/i64", 1, IRType.CODE, 1, 1)   F64_CONVERT_I64_S   = 0xB9, ///  f64.convert_i64_s
        @Instr("f64.convert_i64_u", "f64.convert_u/i64", 1, IRType.CODE, 1, 1)   F64_CONVERT_I64_U   = 0xBA, ///  f64.convert_i64_u
        @Instr("f64.promote_f32", "f64.promote/f32", 1, IRType.CODE, 1, 1)     F64_PROMOTE_F32     = 0xBB, ///  f64.promote_f32
        @Instr("i32.reinterpret_f32", "i32.reinterpret/f32", 1, IRType.CODE, 1, 1) I32_REINTERPRET_F32 = 0xBC, ///  i32.reinterpret_f32
        @Instr("i64.reinterpret_f64", "i64.reinterpret/f64", 1, IRType.CODE, 1, 1) I64_REINTERPRET_F64 = 0xBD, ///  i64.reinterpret_f64
        @Instr("f32.reinterpret_i32", "f32.reinterpret/i32", 1, IRType.CODE, 1, 1) F32_REINTERPRET_I32 = 0xBE, ///  f32.reinterpret_i32
        @Instr("f64.reinterpret_i64", "f64.reinterpret/i64", 1, IRType.CODE, 1, 1) F64_REINTERPRET_I64 = 0xBF, ///  f64.reinterpret_i64
        @Instr("truct_sat", "truct_sat", 1, IRType.CODE, 1, 1, true)     TRUNC_SAT           = 0xFC, ///  TYPE.truct_sat_TYPE_SIGN
            // dfmt on

}

Instr getInstr(IR ir)() {
    enum code = format!q{enum result = getUDAs!(%s, Instr)[0];}(ir.stringof);
    mixin(code);
    return result;
}

version (none) shared static this() {
    static foreach (ir; EnumMembers!IR) {
        {
            enum irInstr = getInstr!ir;
        }
    }
}

static unittest {
    enum InstrUnreachable = Instr("unreachable", "unreachable", 1, IRType.CODE);
    static assert(getInstr!(IR.UNREACHABLE) == InstrUnreachable);
    enum ir = IR.UNREACHABLE;
    static assert(getInstr!(ir) == InstrUnreachable);
}

shared static immutable(Instr[IR]) instrTable;
shared static immutable(IR[string]) irLookupTable;
shared static immutable(Instr[string]) instrWastLookup;

enum PseudoWastInstr {
    invoke = "invoke",
    if_else = "if_else",
    call_import = "call_import",
    local = "local",
    label = "label",
    tableswitch = "tableswitch",
    table = "table",
    case_ = "case",
    memory_size = "memory_size",
}

protected immutable(Instr[IR]) generate_instrTable() {
    Instr[IR] result;
    with (IR) {
        static foreach (E; EnumMembers!IR) {
            {
                enum code = format!q{result[%1$s]=getUDAs!(%1$s, Instr)[0];}(E.stringof);
                mixin(code);
            }
        }
    }
    return assumeUnique(result);
}

shared static this() {
    instrTable = generate_instrTable;
    immutable(IR[string]) generateLookupTable() {
        IR[string] result;
        foreach (ir, ref instr; instrTable) {
            result[instr.name] = ir;
        }
        return assumeUnique(result);
    }

    irLookupTable = generateLookupTable;

    immutable(Instr[string]) generated_instrWastLookup() {
        Instr[string] result;
        static foreach (ir; EnumMembers!IR) {
            {
                enum instr = getInstr!ir;
                result[instr.wast] = instr;
            }
        }
        void setPseudo(const PseudoWastInstr pseudo, const IRType ir_type, const uint pushs = 0, const uint pops = 0) {
            result[pseudo] = Instr("<" ~ pseudo ~ ">", pseudo, uint.max, ir_type, pushs, pops);
        }

        setPseudo(PseudoWastInstr.invoke, IRType.CALL);
        setPseudo(PseudoWastInstr.if_else, IRType.BRANCH, 3, 1);
        setPseudo(PseudoWastInstr.local, IRType.SYMBOL, 0, uint.max);
        setPseudo(PseudoWastInstr.label, IRType.SYMBOL, 1, uint.max);
        setPseudo(PseudoWastInstr.call_import, IRType.CALL);
        setPseudo(PseudoWastInstr.tableswitch, IRType.SYMBOL, uint.max, uint.max);
        setPseudo(PseudoWastInstr.table, IRType.SYMBOL, uint.max);
        setPseudo(PseudoWastInstr.case_, IRType.SYMBOL, uint.max, 1);

        result["i32.select"] = instrTable[IR.SELECT];
        result["i64.select"] = instrTable[IR.SELECT];
        result["f32.select"] = instrTable[IR.SELECT];
        result["f64.select"] = instrTable[IR.SELECT];

        return assumeUnique(result);
    }

    instrWastLookup = generated_instrWastLookup;
}

enum IR_TRUNC_SAT : ubyte {
    @Instr("i32.trunc_sat_f32_s", "i32.trunc_sat_f32_s", 3, IRType.CODE, 1, 1) I32_F32_S,
    @Instr("i32.trunc_sat_f32_u", "i32.trunc_sat_f32_u", 3, IRType.CODE, 1, 1) I32_F32_U,
    @Instr("i32.trunc_sat_f64_s", "i32.trunc_sat_f64_s", 3, IRType.CODE, 1, 1) I32_F64_S,
    @Instr("i32.trunc_sat_f64_u", "i32.trunc_sat_f64_u", 3, IRType.CODE, 1, 1) I32_F64_U,
    @Instr("i64.trunc_sat_f32_s", "i64.trunc_sat_f32_s", 3, IRType.CODE, 1, 1) I64_F32_S,
    @Instr("i64.trunc_sat_f32_u", "i64.trunc_sat_f32_u", 3, IRType.CODE, 1, 1) I64_F32_U,
    @Instr("i64.trunc_sat_f64_s", "i64.trunc_sat_f64_s", 3, IRType.CODE, 1, 1) I64_F64_S,
    @Instr("i64.trunc_sat_f64_u", "i64.trunc_sat_f64_u", 3, IRType.CODE, 1, 1) I64_F64_U,
}

version (none) {
    shared static immutable(string[IR_TRUNC_SAT]) trunc_sat_mnemonic;

    shared static this() {
        with (IR_TRUNC_SAT) {
            trunc_sat_mnemonic = [
                I32_F32_S: "i32.trunc_sat_f32_s",
                I32_F32_U: "i32.trunc_sat_f32_u",
                I32_F64_S: "i32.trunc_sat_f64_s",
                I32_F64_U: "i32.trunc_sat_f64_u",
                I64_F32_S: "i64.trunc_sat_f32_s",
                I64_F32_U: "i64.trunc_sat_f32_u",
                I64_F64_S: "i64.trunc_sat_f64_s",
                I64_F64_U: "i64.trunc_sat_f64_u",
            ];
        }
    }
}

unittest {
    size_t i;
    foreach (E; EnumMembers!IR) {
        assert(E in instrTable);
        i++;
    }
    assert(i == instrTable.length);
}

enum Limits : ubyte {
    INFINITE = 0x00, ///  n:u32       ⇒ {min n, max ε}
    RANGE = 0x01, /// n:u32 m:u32  ⇒ {min n, max m}
}

enum Mutable : ubyte {
    CONST = 0x00,
    VAR = 0x01,
}

enum Types : ubyte {
    EMPTY = 0x40, /// Empty block
    @("func") FUNC = 0x60, /// functype
    @("funcref") FUNCREF = 0x70, /// funcref
    @("i32") I32 = 0x7F, /// i32 valtype
    @("i64") I64 = 0x7E, /// i64 valtype
    @("f32") F32 = 0x7D, /// f32 valtype
    @("f64") F64 = 0x7C, /// f64 valtype
}

template toWasmType(T) {
    static if (is(T == int)) {
        enum toWasmType = Types.I32;
    }
    else static if (is(T == long)) {
        enum toWasmType = Types.I64;
    }
    else static if (is(T == float)) {
        enum toWasmType = Types.F32;
    }
    else static if (is(T == double)) {
        enum toWasmType = Types.F64;
    }
    else static if (isFunctionPointer!T) {
        enum toWasmType = Types.FUNCREF;
    }
    else {
        enum toWasmType = Types.EMPTY;
    }
}

unittest {
    static assert(toWasmType!int  is Types.I32);
    static assert(toWasmType!void  is Types.EMPTY);
}

template toDType(Types t) {
    static if (t is Types.I32) {
        alias toDType = int;
    }
    else static if (t is Types.I64) {
        alias toDType = long;
    }
    else static if (t is Types.F32) {
        alias toDType = float;
    }
    else static if (t is Types.F64) {
        alias toDType = double;
    }
    else static if (t is Types.FUNCREF) {
        alias toDType = void*;
    }
    else {
        alias toDType = void;
    }
}

@safe static string typesName(const Types type) pure {
    import std.uni : toLower;
    import std.conv : to;

    final switch (type) {
        static foreach (E; EnumMembers!Types) {
    case E:
            return toLower(E.to!string);
        }
    }
}

@safe static Types getType(const string name) pure {
    import std.traits;

    switch (name) {
        static foreach (E; EnumMembers!Types) {
            static if (hasUDA!(E, string)) {
    case getUDAs!(E, string)[0]:
                return E;
            }
        }
    default:
        return Types.EMPTY;
    }
}

@safe
unittest {
    assert("f32".getType == Types.F32);
    assert("empty".getType == Types.EMPTY);
    assert("not-valid".getType == Types.EMPTY);

}

enum IndexType : ubyte {
    @("func") FUNC = 0x00, /// func x:typeidx
    @("table") TABLE = 0x01, /// func  tt:tabletype
    @("memory") MEMORY = 0x02, /// mem mt:memtype
    @("global") GLOBAL = 0x03, /// global gt:globaltype
}

@safe static string indexName(const IndexType idx) pure {
    import std.uni : toLower;
    import std.conv : to;

    final switch (idx) {
        foreach (E; EnumMembers!IndexType) {
    case E:
            return toLower(E.to!string);
        }
    }
}

T decode(T)(immutable(ubyte[]) data, ref size_t index) pure {
    size_t byte_size;
    const leb128_index = LEB128.decode!T(data[index .. $]);
    scope (exit) {
        index += leb128_index.size;
    }
    return leb128_index.value;
}

alias u32 = decode!uint;
alias u64 = decode!ulong;
alias i32 = decode!int;
alias i64 = decode!long;

string secname(immutable Section s) @safe {
    import std.exception : assumeUnique;

    return assumeUnique(format("%s_sec", toLower(s.to!string)));
}

alias SectionsT(SectionType) = AliasSeq!(SectionType.Custom, SectionType.Type,
        SectionType.Import, SectionType.Function,
        SectionType.Table, SectionType.Memory, SectionType.Global, SectionType.Export,
        SectionType.Start, SectionType.Element, SectionType.Code, SectionType.Data,);

protected string GenerateInterfaceModule(T...)() {
    import std.array : join;

    string[] result;
    static foreach (i, E; EnumMembers!Section) {
        result ~= format(q{alias SecType_%s=T[Section.%s];}, i, E);
        result ~= format(q{void %s(ref ConstOf!(SecType_%s) sec);}, secname(E), i);
    }
    return result.join("\n");
}

interface InterfaceModuleT(T...) {
    enum code = GenerateInterfaceModule!(T)();
    mixin(code);
}

version (none) bool isWasmModule(alias M)() @safe if (is(M == struct) || is(M == class)) {
    import std.algorithm;

    enum all_members = [__traits(allMembers, M)];
    return [EnumMembers!Section]
        .map!(sec => sec.secname)
        .all!(name => all_members.canFind(name));
}

@safe struct WasmArg {
    protected {
        Types _type;
        union {
            @(Types.I32) int i32;
            @(Types.I64) long i64;
            @(Types.F32) float f32;
            @(Types.F64) double f64;
        }
    }

    static WasmArg undefine() pure nothrow {
        WasmArg result;
        result._type = Types.EMPTY;
        return result;
    }

    void opAssign(T)(T x) nothrow {
        alias BaseT = Unqual!T;
        static if (is(BaseT == int) || is(BaseT == uint)) {
            _type = Types.I32;
            i32 = cast(int) x;
        }
        else static if (is(BaseT == long) || is(BaseT == ulong)) {
            _type = Types.I64;
            i64 = cast(long) x;
        }
        else static if (is(BaseT == float)) {
            _type = Types.F32;
            f32 = x;
        }
        else static if (is(BaseT == double)) {
            _type = Types.F64;
            f64 = x;
        }
        else static if (is(BaseT == WasmArg)) {
            emplace!WasmArg(&this, x);
        }
        else {
            static assert(0, format("Type %s is not supported by WasmArg", T.stringof));
        }
    }

    T get(T)() const {
        alias BaseT = Unqual!T;
        static if (is(BaseT == int) || is(BaseT == uint)) {
            check(_type is Types.I32, format("Wrong to type %s execpted %s", _type, Types.I32));
            return cast(T) i32;
        }
        else static if (is(BaseT == long) || is(BaseT == ulong)) {
            check(_type is Types.I64, format("Wrong to type %s execpted %s", _type, Types.I64));
            return cast(T) i64;
        }
        else static if (is(BaseT == float)) {
            check(_type is Types.F32, format("Wrong to type %s execpted %s", _type, Types.F32));
            return f32;
        }
        else static if (is(BaseT == double)) {
            check(_type is Types.F64, format("Wrong to type %s execpted %s", _type, Types.F64));
            return f64;
        }
    }

    @property Types type() const pure nothrow {
        return _type;
    }

}

static assert(isInputRange!ExprRange);
@safe struct ExprRange {
    immutable(ubyte[]) data;

    protected {
        size_t _index;
        int _level;
        IRElement current;
        WasmException wasm_exception;
    }

    const(WasmException) exception() const pure nothrow @nogc {
        return wasm_exception;
    }

    struct IRElement {
        IR code;
        int level;
        private {
            WasmArg _warg;
            WasmArg[] _wargs;
            const(Types)[] _types;
        }

        enum unreachable = IRElement(IR.UNREACHABLE);

        const(WasmArg) warg() const pure nothrow {
            return _warg;
        }

        const(WasmArg[]) wargs() const pure nothrow {
            return _wargs;
        }

        const(Types[]) types() const pure nothrow {
            return _types;
        }

    }

    this(immutable(ubyte[]) data) pure nothrow {
        this.data = data;
        set_front(current, _index);
    }

    @safe protected void set_front(ref scope IRElement elm, ref size_t index) pure nothrow {
        @trusted void set(ref WasmArg warg, const Types type) pure nothrow {
            with (Types) {
                switch (type) {
                case I32:
                    warg = i32(data, index);
                    break;
                case I64:
                    warg = i64(data, index);
                    break;
                case F32:
                    warg = data.binpeek!(float, Endian.littleEndian)(&index);
                    break;
                case F64:
                    warg = data.binpeek!(double, Endian.littleEndian)(&index);
                    break;
                default:
                    assumeWontThrow({
                        wasm_exception = new WasmException(format(
                            "Assembler argument type not vaild as an argument %s", type));
                    });
                }
            }
        }

        if (index < data.length) {
            elm.code = cast(IR) data[index];
            elm._types = null;
            const instr = instrTable[elm.code];
            index += IR.sizeof;
            with (IRType) {
                final switch (instr.irtype) {
                case CODE:
                    break;
                case PREFIX:
                    elm._warg = int(data[index]); // Extened insruction
                    index += ubyte.sizeof;
                    break;
                case BLOCK:
                    elm._types = [cast(Types) data[index]];
                    index += Types.sizeof;
                    _level++;
                    break;
                case BRANCH:
                case BRANCH_IF:
                    // branchidx
                    set(elm._warg, Types.I32);
                    _level++;
                    break;
                case BRANCH_TABLE:
                    //size_t vec_size;
                    const len = u32(data, index) + 1;
                    elm._wargs = new WasmArg[len];
                    foreach (ref a; elm._wargs) {
                        a = u32(data, index);
                    }
                    break;
                case CALL:
                    // callidx
                    set(elm._warg, Types.I32);
                    break;
                case CALL_INDIRECT:
                    // typeidx
                    set(elm._warg, Types.I32);
                    if (!(data[index] == 0x00)) {
                        wasm_exception = new WasmException("call_indirect should end with 0x00");
                    }
                    index += ubyte.sizeof;
                    break;
                case LOCAL, GLOBAL:
                    // localidx globalidx
                    set(elm._warg, Types.I32);
                    break;
                case MEMORY:
                    // offset
                    elm._wargs = new WasmArg[2];
                    set(elm._wargs[0], Types.I32);
                    // align
                    set(elm._wargs[1], Types.I32);
                    break;
                case MEMOP:
                    index++;
                    break;
                case CONST:
                    with (IR) {
                        switch (elm.code) {
                        case I32_CONST:
                            set(elm._warg, Types.I32);
                            break;
                        case I64_CONST:
                            set(elm._warg, Types.I64);
                            break;
                        case F32_CONST:
                            set(elm._warg, Types.F32);
                            break;
                        case F64_CONST:
                            set(elm._warg, Types.F64);
                            break;
                        default:
                            assert(0, format("Instruction %s is not a const", elm.code));
                        }
                    }
                    break;
                case END:
                    _level--;
                    break;
                case SYMBOL:
                    assert(0, "Symbol opcode and it does not have an equivalent opcode");
                }

            }
        }
        else {
            if (index == data.length) {
                index++;
            }
            elm.code = IR.UNREACHABLE;
        }
    }

    @property pure nothrow {
        const(size_t) index() const {
            return _index;
        }

        const(IRElement) front() const {
            return current;
        }

        bool empty() const {
            return _index > data.length || (wasm_exception !is null);
        }

        void popFront() {
            set_front(current, _index);
        }
    }

}
