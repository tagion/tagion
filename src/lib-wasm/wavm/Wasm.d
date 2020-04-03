module wavm.Wasm;

import std.format;
import wavm.WAVMException;
import LEB128=wavm.LEB128;

import std.stdio;
import std.meta : AliasSeq;
import std.traits : EnumMembers, getUDAs, Unqual;

import std.bitmanip : binread = read, binwrite = write, binpeek=peek, Endian;

@safe
class WASMException : WAVMException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}


alias check=Check!WASMException;

@safe
struct Wasm {
    protected immutable(ubyte[]) _data;

    immutable(ubyte[]) data() const pure nothrow {
        return _data;
    }

    this(immutable(ubyte[]) data) pure nothrow {
        _data=data;
    }

    enum IRType {
        CODE,          /// Simple instruction with no argument
        BLOCK,         /// Block instruction
        BRANCH,        /// Branch jump instruction
        BRANCH_TABLE,  /// Branch table jump instruction
        CALL,          /// Subroutine call
        CALL_INDIRECT, /// Indirect subroutine call
        LOCAL,         /// Local register storage instruction
        GLOBAL,        /// Global register storage instruction
        MEMORY,        /// Memory instruction
        MEMOP,         /// Memory management instruction
        CONST,         /// Constant argument
        END            /// Block end instruction
    }

    struct Instr {
        string name;
        uint cost;
        IRType irtype;
        Types  args;
    }

    enum ubyte[] magic=[0x00, 0x61, 0x73, 0x6D];
    enum ubyte[] wasm_version=[0x01, 0x00, 0x00, 0x00];
    enum IR : ubyte {
        UNREACHABLE         = 0x00, ///  unreachable
            NOP                 = 0x01, ///  nop
            BLOCK               = 0x02, ///  block rt:blocktype (in:instr) * end
            LOOP                = 0x03, ///  loop rt:blocktype (in:instr) * end
            IF                  = 0x04, /++     if rt:blocktype (in:instr) *rt in * else ? end
                                         if rt:blocktype (in1:instr) *rt in * 1 else (in2:instr) * end
                                         +/
            ELSE                = 0x05, ///  else
            END                 = 0x0B, ///  end
            BR                  = 0x0C, ///  br l:labelidx
            BR_IF               = 0x0D, ///  br_if l:labelidx
            BR_TABLE            = 0x0E, ///  br_table l:vec(labelidx) * lN:labelidx
            RETURN              = 0x0F, ///  return
            CALL                = 0x10, ///  call x:funcidx
            CALL_INDIRECT       = 0x11, ///  call_indirect x:typeidx 0x00
            DROP                = 0x1A, ///  drop
            SELECT              = 0x1B, ///  select
            LOCAL_GET           = 0x20, ///  local.get x:localidx
            LOCAL_SET           = 0x21, ///  local.set x:localidx
            LOCAL_TEE           = 0x22, ///  local.tee x:localidx
            GLOBAL_GET          = 0x23, ///  global.get x:globalidx
            GLOBAL_SET          = 0x24, ///  global.set x:globalidx

            I32_LOAD            = 0x28, ///  i32.load     m:memarg
            I64_LOAD            = 0x29, ///  i64.load     m:memarg
            F32_LOAD            = 0x2A, ///  f32.load     m:memarg
            F64_LOAD            = 0x2B, ///  f64.load     m:memarg
            I32_LOAD8_S         = 0x2C, ///  i32.load8_s  m:memarg
            I32_LOAD8_U         = 0x2D, ///  i32.load8_u  m:memarg
            I32_LOAD16_S        = 0x2E, ///  i32.load16_s m:memarg
            I32_LOAD16_U        = 0x2F, ///  i32.load16_u m:memarg
            I64_LOAD8_S         = 0x30, ///  i64.load8_s  m:memarg
            I64_LOAD8_U         = 0x31, ///  i64.load8_u  m:memarg
            I64_LOAD16_S        = 0x32, ///  i64.load16_s m:memarg
            I64_LOAD16_U        = 0x33, ///  i64.load16_u m:memarg
            I64_LOAD32_S        = 0x34, ///  i64.load32_s m:memarg
            I64_LOAD32_U        = 0x35, ///  i64.load32_u m:memarg
            I32_STORE           = 0x36, ///  i32.store    m:memarg
            I64_STORE           = 0x37, ///  i64.store    m:memarg
            F32_STORE           = 0x38, ///  f32.store    m:memarg
            F64_STORE           = 0x39, ///  f64.store    m:memarg
            I32_STORE8          = 0x3A, ///  i32.store8   m:memarg
            I32_STORE16         = 0x3B, ///  i32.store16  m:memarg
            I64_STORE8          = 0x3C, ///  i64.store8   m:memarg
            I64_STORE16         = 0x3D, ///  i64.store16  m:memarg
            I64_STORE32         = 0x3E, ///  i64.store32  m:memarg
            MEMORY_SIZE         = 0x3F, ///  memory.size  0x00
            MEMORY_GROW         = 0x40, ///  memory.grow  0x00

            I32_CONST           = 0x41, ///  i32.const n:i32
            I64_CONST           = 0x42, ///  i64.const n:i64
            F32_CONST           = 0x43, ///  f32.const z:f32
            F64_CONST           = 0x44, ///  f64.const z:f64

            I32_EQZ             = 0x45, ///  i32.eqz
            I32_EQ              = 0x46, ///  i32.eq
            I32_NE              = 0x47, ///  i32.ne
            I32_LT_S            = 0x48, ///  i32.lt_s
            I32_LT_U            = 0x49, ///  i32.lt_u
            I32_GT_S            = 0x4A, ///  i32.gt_s
            I32_GT_U            = 0x4B, ///  i32.gt_u
            I32_LE_S            = 0x4C, ///  i32.le_s
            I32_LE_U            = 0x4D, ///  i32.le_u
            I32_GE_S            = 0x4E, ///  i32.ge_s
            I32_GE_U            = 0x4F, ///  i32.ge_u

            I64_EQZ             = 0x50, ///  i64.eqz
            I64_EQ              = 0x51, ///  i64.eq
            I64_NE              = 0x52, ///  i64.ne
            I64_LT_S            = 0x53, ///  i64.lt_s

            I64_LT_U            = 0x54, ///  i64.lt_u
            I64_GT_S            = 0x55, ///  i64.gt_s
            I64_GT_U            = 0x56, ///  i64.gt_u
            i64_le_s            = 0x57, ///  i64.le_s
            I64_LE_U            = 0x58, ///  i64.le_u
            I64_GE_S            = 0x59, ///  i64.ge_s
            I64_GE_U            = 0x5A, ///  i64.ge_u

            F32_EQ              = 0x5B, ///  f32.eq
            F32_NE              = 0x5C, ///  f32.ne
            F32_LT              = 0x5D, ///  f32.lt
            F32_GT              = 0x5E, ///  f32.gt
            F32_LE              = 0x5F, ///  f32.le
            F32_GE              = 0x60, ///  f32.ge

            F64_EQ              = 0x61, ///  f64.eq
            F64_NE              = 0x62, ///  f64.ne
            F64_LT              = 0x63, ///  f64.lt
            F64_GT              = 0x64, ///  f64.gt
            F64_LE              = 0x65, ///  f64.le
            F64_GE              = 0x66, ///  f64.ge


            I32_CLZ             = 0x67, ///  i32.clz
            I32_CTZ             = 0x68, ///  i32.ctz
            I32_POPCNT          = 0x69, ///  i32.popcnt
            I32_ADD             = 0x6A, ///  i32.add
            I32_SUB             = 0x6B, ///  i32.sub
            I32_MUL             = 0x6C, ///  i32.mul
            I32_DIV_S           = 0x6D, ///  i32.div_s
            I32_DIV_U           = 0x6E, ///  i32.div_u
            I32_REM_S           = 0x6F, ///  i32.rem_s
            I32_REM_U           = 0x70, ///  i32.rem_u
            I32_AND             = 0x71, ///  i32.and
            I32_OR              = 0x72, ///  i32.or
            I32_XOR             = 0x73, ///  i32.xor
            I32_SHL             = 0x74, ///  i32.shl
            I32_SHR_S           = 0x75, ///  i32.shr_s
            I32_SHR_U           = 0x76, ///  i32.shr_u
            I32_ROTL            = 0x77, ///  i32.rotl
            I32_ROTR            = 0x78, ///  i32.rotr

            I64_CLZ             = 0x79, ///  i64.clz
            I64_CTZ             = 0x7A, ///  i64.ctz
            I64_POPCNT          = 0x7B, ///  i64.popcnt
            I64_ADD             = 0x7C, ///  i64.add
            I64_SUB             = 0x7D, ///  i64.sub
            I64_MUL             = 0x7E, ///  i64.mul
            I64_DIV_S           = 0x7F, ///  i64.div_s
            I64_DIV_U           = 0x80, ///  i64.div_u
            I64_REM_S           = 0x81, ///  i64.rem_s
            I64_REM_U           = 0x82, ///  i64.rem_u
            I64_AND             = 0x83, ///  i64.and
            I64_OR              = 0x84, ///  i64.or
            I64_XOR             = 0x85, ///  i64.xor
            I64_SHL             = 0x86, ///  i64.shl
            I64_SHR_S           = 0x87, ///  i64.shr_s
            I64_SHR_U           = 0x88, ///  i64.shr_u
            I64_ROTL            = 0x89, ///  i64.rotl
            I64_ROTR            = 0x8A, ///  i64.rotr

            F32_ABS             = 0x8B, ///  f32.abs
            F32_NEG             = 0x8C, ///  f32.neg
            F32_CEIL            = 0x8D, ///  f32.ceil
            F32_FLOOR           = 0x8E, ///  f32.floor
            F32_TRUNC           = 0x8F, ///  f32.trunc
            F32_NEAREST         = 0x90, ///  f32.nearest
            F32_SQRT            = 0x91, ///  f32.sqrt
            F32_ADD             = 0x92, ///  f32.add
            F32_SUB             = 0x93, ///  f32.sub
            F32_MUL             = 0x94, ///  f32.mul
            F32_DIV             = 0x95, ///  f32.div
            F32_MIN             = 0x96, ///  f32.min
            F32_MAX             = 0x97, ///  f32.max
            F32_COPYSIGN        = 0x98, ///  f32.copysign

            F64_ABS             = 0x99, ///  f64.abs
            F64_NEG             = 0x9A, ///  f64.neg
            F64_CEIL            = 0x9B, ///  f64.ceil
            F64_FLOOR           = 0x9C, ///  f64.floor
            F64_TRUNC           = 0x9D, ///  f64.trunc
            F64_NEAREST         = 0x9E, ///  f64.nearest
            F64_SQRT            = 0x9F, ///  f64.sqrt
            F64_ADD             = 0xA0, ///  f64.add
            F64_SUB             = 0xA1, ///  f64.sub
            F64_MUL             = 0xA2, ///  f64.mul
            F64_DIV             = 0xA3, ///  f64.div
            F64_MIN             = 0xA4, ///  f64.min
            F64_MAX             = 0xA5, ///  f64.max
            F64_COPYSIGN        = 0xA6, ///  f64.copysign

            I32_WRAP_I64        = 0xA7, ///  i32.wrap_i64
            I32_TRUNC_F32_S     = 0xA8, ///  i32.trunc_f32_s
            I32_TRUNC_F32_U     = 0xA9, ///  i32.trunc_f32_u
            I32_TRUNC_F64_S     = 0xAA, ///  i32.trunc_f64_s
            I32_TRUNC_F64_U     = 0xAB, ///  i32.trunc_f64_u
            I64_EXTEND_I32_S    = 0xAC, ///  i64.extend_i32_s
            I64_EXTEND_I32_U    = 0xAD, ///  i64.extend_i32_u
            I64_TRUNC_F32_S     = 0xAE, ///  i64.trunc_f32_s
            I64_TRUNC_F32_U     = 0xAF, ///  i64.trunc_f32_u
            I64_TRUNC_F64_S     = 0xB0, ///  i64.trunc_f64_s
            I64_TRUNC_F64_U     = 0xB1, ///  i64.trunc_f64_u
            F32_CONVERT_I32_S   = 0xB2, ///  f32.convert_i32_s
            F32_CONVERT_I32_U   = 0xB3, ///  f32.convert_i32_u
            F32_CONVERT_I64_S   = 0xB4, ///  f32.convert_i64_s
            F32_CONVERT_I64_U   = 0xB5, ///  f32.convert_i64_u
            F32_DEMOTE_F64      = 0xB6, ///  f32.demote_f64
            F64_CONVERT_I32_S   = 0xB7, ///  f64.convert_i32_s
            F64_CONVERT_I32_U   = 0xB8, ///  f64.convert_i32_u
            F64_CONVERT_I64_S   = 0xB9, ///  f64.convert_i64_s
            F64_CONVERT_I64_U   = 0xBA, ///  f64.convert_i64_u
            F64_PROMOTE_F32     = 0xBB, ///  f64.promote_f32
            I32_REINTERPRET_F32 = 0xBC, ///  i32.reinterpret_f32
            I64_REINTERPRET_F64 = 0xBD, ///  i64.reinterpret_f64
            F32_REINTERPRET_I32 = 0xBE, ///  f32.reinterpret_i32
            F64_REINTERPRET_I64 = 0xBF, ///  f64.reinterpret_i64


            }

    shared static  immutable(Instr[IR]) instrTable;

    shared static this() {
        with(IR) {
            instrTable = [
                UNREACHABLE         : Instr("unreachable", 1, IRType.CODE),
                NOP                 : Instr("nop", 1, IRType.CODE),
                BLOCK               : Instr("block", 0, IRType.BLOCK),
                LOOP                : Instr("loop", 0, IRType.BLOCK),
                IF                  : Instr("if", 1, IRType.CODE),


                ELSE                : Instr("else", 0, IRType.END),
                END                 : Instr("end", 0, IRType.END),
                BR                  : Instr("br", 1, IRType.BRANCH),
                BR_IF               : Instr("br_if", 1, IRType.BRANCH),
                BR_TABLE            : Instr("br_table", 1, IRType.BRANCH_TABLE),
                RETURN              : Instr("return", 1, IRType.CODE),
                CALL                : Instr("call", 1, IRType.CALL),
                CALL_INDIRECT       : Instr("call_indirect", 1, IRType.CALL_INDIRECT),
                DROP                : Instr("drop", 1, IRType.CODE),
                SELECT              : Instr("select", 1, IRType.CODE),
                LOCAL_GET           : Instr("local.get", 1, IRType.LOCAL),
                LOCAL_SET           : Instr("local.set", 1, IRType.LOCAL),
                LOCAL_TEE           : Instr("local.tee", 1, IRType.LOCAL),
                GLOBAL_GET          : Instr("global.get", 1, IRType.GLOBAL),
                GLOBAL_SET          : Instr("global.set", 1, IRType.GLOBAL),
/// memarg a                     :u32 o:u32 ⇒ {align a, offset o}
                I32_LOAD            : Instr("i32.load", 2, IRType.MEMORY),
                I64_LOAD            : Instr("i64.load", 2, IRType.MEMORY),
                F32_LOAD            : Instr("f32.load", 2, IRType.MEMORY),
                F64_LOAD            : Instr("f64.load", 2, IRType.MEMORY),
                I32_LOAD8_S         : Instr("i32.load8_s", 2, IRType.MEMORY),
                I32_LOAD8_U         : Instr("i32.load8_u", 2, IRType.MEMORY),
                I32_LOAD16_S        : Instr("i32.load16_s", 2, IRType.MEMORY),
                I32_LOAD16_U        : Instr("i32.load16_u", 2, IRType.MEMORY),
                I64_LOAD8_S         : Instr("i64.load8_s", 2, IRType.MEMORY),
                I64_LOAD8_U         : Instr("i64.load8_u", 2, IRType.MEMORY),
                I64_LOAD16_S        : Instr("i64.load16_s", 2, IRType.MEMORY),
                I64_LOAD16_U        : Instr("i64.load16_u", 2, IRType.MEMORY),
                I64_LOAD32_S        : Instr("i64.load32_s", 2, IRType.MEMORY),
                I64_LOAD32_U        : Instr("i64.load32_u", 2, IRType.MEMORY),
                I32_STORE           : Instr("i32.store", 2, IRType.MEMORY),
                I64_STORE           : Instr("i64.store", 2, IRType.MEMORY),
                F32_STORE           : Instr("f32.store", 2, IRType.MEMORY),
                F64_STORE           : Instr("f64.store", 2, IRType.MEMORY),
                I32_STORE8          : Instr("i32.store8", 2, IRType.MEMORY),
                I32_STORE16         : Instr("i32.store16", 2, IRType.MEMORY),
                I64_STORE8          : Instr("i64.store8", 2, IRType.MEMORY),
                I64_STORE16         : Instr("i64.store16", 2, IRType.MEMORY),
                I64_STORE32         : Instr("i64.store32", 2, IRType.MEMORY),
                MEMORY_SIZE         : Instr("memory.size", 7, IRType.MEMOP),
                MEMORY_GROW         : Instr("memory.grow", 7, IRType.MEMOP),
                // Const instructions
                I32_CONST           : Instr("i32.const", 1, IRType.CONST),
                I64_CONST           : Instr("i64.const", 1, IRType.CONST),
                F32_CONST           : Instr("f32.const", 1, IRType.CONST),
                F64_CONST           : Instr("f64.const", 1, IRType.CONST),
                // Compare instructions
                I32_EQZ             : Instr("i32.eqz", 1, IRType.CODE),
                I32_EQ              : Instr("i32.eq", 1, IRType.CODE),
                I32_NE              : Instr("i32.ne", 1, IRType.CODE),
                I32_LT_S            : Instr("i32.lt_s", 1, IRType.CODE),
                I32_LT_U            : Instr("i32.lt_u", 1, IRType.CODE),
                I32_GT_S            : Instr("i32.gt_s", 1, IRType.CODE),
                I32_GT_U            : Instr("i32.gt_u", 1, IRType.CODE),
                I32_LE_S            : Instr("i32.le_s", 1, IRType.CODE),
                I32_LE_U            : Instr("i32.le_u", 1, IRType.CODE),
                I32_GE_S            : Instr("i32.ge_s", 1, IRType.CODE),
                I32_GE_U            : Instr("i32.ge_u", 1, IRType.CODE),

                I64_EQZ             : Instr("i64.eqz", 1, IRType.CODE),
                I64_EQ              : Instr("i64.eq", 1, IRType.CODE),
                I64_NE              : Instr("i64.ne", 1, IRType.CODE),
                I64_LT_S            : Instr("i64.lt_s", 1, IRType.CODE),

                I64_LT_U            : Instr("i64.lt_u", 1, IRType.CODE),
                I64_GT_S            : Instr("i64.gt_s", 1, IRType.CODE),
                I64_GT_U            : Instr("i64.gt_u", 1, IRType.CODE),
                i64_le_s            : Instr("i64.le_s", 1, IRType.CODE),
                I64_LE_U            : Instr("i64.le_u", 1, IRType.CODE),
                I64_GE_S            : Instr("i64.ge_s", 1, IRType.CODE),
                I64_GE_U            : Instr("i64.ge_u", 1, IRType.CODE),

                F32_EQ              : Instr("f32.eq", 1, IRType.CODE),
                F32_NE              : Instr("f32.ne", 1, IRType.CODE),
                F32_LT              : Instr("f32.lt", 1, IRType.CODE),
                F32_GT              : Instr("f32.gt", 1, IRType.CODE),
                F32_LE              : Instr("f32.le", 1, IRType.CODE),
                F32_GE              : Instr("f32.ge", 1, IRType.CODE),

                F64_EQ              : Instr("f64.eq", 1, IRType.CODE),
                F64_NE              : Instr("f64.ne", 1, IRType.CODE),
                F64_LT              : Instr("f64.lt", 1, IRType.CODE),
                F64_GT              : Instr("f64.gt", 1, IRType.CODE),
                F64_LE              : Instr("f64.le", 1, IRType.CODE),
                F64_GE              : Instr("f64.ge", 1, IRType.CODE),

                /// Operator                      instructions
                I32_CLZ             : Instr("i32.clz", 1, IRType.CODE),
                I32_CTZ             : Instr("i32.ctz", 1, IRType.CODE),
                I32_POPCNT          : Instr("i32.popcnt", 1, IRType.CODE),
                I32_ADD             : Instr("i32.add", 1, IRType.CODE),
                I32_SUB             : Instr("i32.sub", 1, IRType.CODE),
                I32_MUL             : Instr("i32.mul", 1, IRType.CODE),
                I32_DIV_S           : Instr("i32.div_s", 1, IRType.CODE),
                I32_DIV_U           : Instr("i32.div_u", 1, IRType.CODE),
                I32_REM_S           : Instr("i32.rem_s", 1, IRType.CODE),
                I32_REM_U           : Instr("i32.rem_u", 1, IRType.CODE),
                I32_AND             : Instr("i32.and", 1, IRType.CODE),
                I32_OR              : Instr("i32.or", 1, IRType.CODE),
                I32_XOR             : Instr("i32.xor", 1, IRType.CODE),
                I32_SHL             : Instr("i32.shl", 1, IRType.CODE),
                I32_SHR_S           : Instr("i32.shr_s", 1, IRType.CODE),
                I32_SHR_U           : Instr("i32.shr_u", 1, IRType.CODE),
                I32_ROTL            : Instr("i32.rotl", 1, IRType.CODE),
                I32_ROTR            : Instr("i32.rotr", 1, IRType.CODE),

                I64_CLZ             : Instr("i64.clz", 1, IRType.CODE),
                I64_CTZ             : Instr("i64.ctz", 1, IRType.CODE),
                I64_POPCNT          : Instr("i64.popcnt", 1, IRType.CODE),
                I64_ADD             : Instr("i64.add", 1, IRType.CODE),
                I64_SUB             : Instr("i64.sub", 1, IRType.CODE),
                I64_MUL             : Instr("i64.mul", 1, IRType.CODE),
                I64_DIV_S           : Instr("i64.div_s", 1, IRType.CODE),
                I64_DIV_U           : Instr("i64.div_u", 1, IRType.CODE),
                I64_REM_S           : Instr("i64.rem_s", 1, IRType.CODE),
                I64_REM_U           : Instr("i64.rem_u", 1, IRType.CODE),
                I64_AND             : Instr("i64.and", 1, IRType.CODE),
                I64_OR              : Instr("i64.or", 1, IRType.CODE),
                I64_XOR             : Instr("i64.xor", 1, IRType.CODE),
                I64_SHL             : Instr("i64.shl", 1, IRType.CODE),
                I64_SHR_S           : Instr("i64.shr_s", 1, IRType.CODE),
                I64_SHR_U           : Instr("i64.shr_u", 1, IRType.CODE),
                I64_ROTL            : Instr("i64.rotl", 1, IRType.CODE),
                I64_ROTR            : Instr("i64.rotr", 1, IRType.CODE),

                F32_ABS             : Instr("f32.abs", 1, IRType.CODE),
                F32_NEG             : Instr("f32.neg", 1, IRType.CODE),
                F32_CEIL            : Instr("f32.ceil", 1, IRType.CODE),
                F32_FLOOR           : Instr("f32.floor", 1, IRType.CODE),
                F32_TRUNC           : Instr("f32.trunc", 1, IRType.CODE),
                F32_NEAREST         : Instr("f32.nearest", 1, IRType.CODE),
                F32_SQRT            : Instr("f32.sqrt", 3, IRType.CODE),
                F32_ADD             : Instr("f32.add", 3, IRType.CODE),
                F32_SUB             : Instr("f32.sub", 3, IRType.CODE),
                F32_MUL             : Instr("f32.mul", 3, IRType.CODE),
                F32_DIV             : Instr("f32.div", 3, IRType.CODE),
                F32_MIN             : Instr("f32.min", 1, IRType.CODE),
                F32_MAX             : Instr("f32.max", 1, IRType.CODE),
                F32_COPYSIGN        : Instr("f32.copysign", 1, IRType.CODE),

                F64_ABS             : Instr("f64.abs", 1, IRType.CODE),
                F64_NEG             : Instr("f64.neg", 1, IRType.CODE),
                F64_CEIL            : Instr("f64.ceil", 1, IRType.CODE),
                F64_FLOOR           : Instr("f64.floor", 1, IRType.CODE),
                F64_TRUNC           : Instr("f64.trunc", 1, IRType.CODE),
                F64_NEAREST         : Instr("f64.nearest", 1, IRType.CODE),
                F64_SQRT            : Instr("f64.sqrt", 3, IRType.CODE),
                F64_ADD             : Instr("f64.add", 3, IRType.CODE),
                F64_SUB             : Instr("f64.sub", 3, IRType.CODE),
                F64_MUL             : Instr("f64.mul", 3, IRType.CODE),
                F64_DIV             : Instr("f64.div", 3, IRType.CODE),
                F64_MIN             : Instr("f64.min", 1, IRType.CODE),
                F64_MAX             : Instr("f64.max", 1, IRType.CODE),
                F64_COPYSIGN        : Instr("f64.copysign", 1, IRType.CODE),
                /// Convert instructions
                I32_WRAP_I64        : Instr("i32.wrap_i64", 1, IRType.CODE),
                I32_TRUNC_F32_S     : Instr("i32.trunc_f32_s", 1, IRType.CODE),
                I32_TRUNC_F32_U     : Instr("i32.trunc_f32_u", 1, IRType.CODE),
                I32_TRUNC_F64_S     : Instr("i32.trunc_f64_s", 1, IRType.CODE),
                I32_TRUNC_F64_U     : Instr("i32.trunc_f64_u", 1, IRType.CODE),
                I64_EXTEND_I32_S    : Instr("i64.extend_i32_s", 1, IRType.CODE),
                I64_EXTEND_I32_U    : Instr("i64.extend_i32_u", 1, IRType.CODE),
                I64_TRUNC_F32_S     : Instr("i64.trunc_f32_s", 1, IRType.CODE),
                I64_TRUNC_F32_U     : Instr("i64.trunc_f32_u", 1, IRType.CODE),
                I64_TRUNC_F64_S     : Instr("i64.trunc_f64_s", 1, IRType.CODE),
                I64_TRUNC_F64_U     : Instr("i64.trunc_f64_u", 1, IRType.CODE),
                F32_CONVERT_I32_S   : Instr("f32.convert_i32_s", 1, IRType.CODE),
                F32_CONVERT_I32_U   : Instr("f32.convert_i32_u", 1, IRType.CODE),
                F32_CONVERT_I64_S   : Instr("f32.convert_i64_s", 1, IRType.CODE),
                F32_CONVERT_I64_U   : Instr("f32.convert_i64_u", 1, IRType.CODE),
                F32_DEMOTE_F64      : Instr("f32.demote_f64", 1, IRType.CODE),
                F64_CONVERT_I32_S   : Instr("f64.convert_i32_s", 1, IRType.CODE),
                F64_CONVERT_I32_U   : Instr("f64.convert_i32_u", 1, IRType.CODE),
                F64_CONVERT_I64_S   : Instr("f64.convert_i64_s", 1, IRType.CODE),
                F64_CONVERT_I64_U   : Instr("f64.convert_i64_u", 1, IRType.CODE),
                F64_PROMOTE_F32     : Instr("f64.promote_f32", 1, IRType.CODE),
                I32_REINTERPRET_F32 : Instr("i32.reinterpret_f32", 1, IRType.CODE),
                I64_REINTERPRET_F64 : Instr("i64.reinterpret_f64", 1, IRType.CODE),
                F32_REINTERPRET_I32 : Instr("f32.reinterpret_i32", 1, IRType.CODE),
                F64_REINTERPRET_I64 : Instr("f64.reinterpret_i64", 1, IRType.CODE),

                ];
        }
    }



    unittest {
        size_t i;
        foreach(E; EnumMembers!IR) {
            assert(E in instrTable);
            i++;
        }
        assert(i == instrTable.length);
    }

    enum Limits : ubyte {
        LOWER = 0x00, ///  n:u32       ⇒ {min n, max ε}
            RANGE = 0x01, /// n:u32 m:u32  ⇒ {min n, max m}
            }

    enum Mutable : ubyte {
        CONST = 0x00,
            VAR = 0x01,
            }

    enum Types : ubyte {
        EMPTY = 0x40,     /// Empty block
            FUNC = 0x60,  /// functype
            FUNCREF = 0x70,  /// funcref
            I32 = 0x7F,   /// i32 valtype
            I64 = 0x7E,   /// i64 valtype
            F32 = 0x7D,   /// f32 valtype
            F64 = 0x7C,   /// f64 valtype
            }

    enum IndexType : ubyte {
        FUNC =   0x00, /// func x:typeidx
            TABLE =     0x01, /// func  tt:tabletype
            MEM =       0x02, /// mem mt:memtype
            GLOBAL =    0x03, /// global gt:globaltype
            }

    enum Section : ubyte {
        CUSTOM   = 0,
            TYPE     = 1,
            IMPORT   = 2,
            FUNCTION = 3,
            TABLE    = 4,
            MEMORY   = 5,
            GLOBAL   = 6,
            EXPORT   = 7,
            START    = 8,
            ELEMENT  = 9,
            CODE     = 10,
            DATA     = 11
            }


// OpcodeRange WasmSections opSlice() {
//     return OpcodeRange(data);
// }

    @trusted
    static uint calc_size(const(ubyte[]) data) pure {
        return *cast(uint*)(data[0..uint.sizeof].ptr);
    }

    @trusted
    static immutable(T[]) Vector(T)(immutable(ubyte[]) vec_data, out size_t index) {
//        size_t index;
//        size_t u32_size;
        immutable len=u32(vec_data, index);
        // writefln("vec_data=%s", vec_data);
        // writefln("[%d..%d]", index, index+len*T.sizeof);
        //index=u32_size;
        immutable vec_mem=vec_data[index..index+len*T.sizeof];
        index+=len*T.sizeof;
        // immutable len=vec_mem.length / T.sizeof;
        // pragma(msg, "Fixme(cbr): this assert should be an exception");
        // assert(T.sizeof % vec_mem.length == 0,
        //     format("The vector memory (size=%d) does not match the size of %s",
        //         vec_mem.length, T.stringof));
        immutable result=cast(immutable(T*))(vec_mem.ptr);
        return result[0..len];
    }

    WasmRange opSlice() {
        return WasmRange(data);
    }

    alias u32=LEB128.decode!uint;
    alias u64=LEB128.decode!ulong;
    alias i32=LEB128.decode!int;
    alias i64=LEB128.decode!long;
    struct WasmRange {
        immutable(ubyte[]) data;
        protected size_t _index;

        this(immutable(ubyte[]) data) {
            this.data=data;
            _index=2*uint.sizeof;
            //   writefln("WasmRange %s", data);
        }

        @property bool empty() const pure nothrow {
            return _index >= data.length;
        }

        @property WasmSection front() const pure {
            return WasmSection(data[_index..$]);
        }

        @property void popFront() {
            size_t u32_size;
            _index+=Section.sizeof;
            const size=u32(data[_index..$], u32_size);
            _index+=u32_size+size;
            // writefln("popFront %d", _index);
        }

        struct WasmSection {
            //enum SIZE_POS=Section.sizeof;
            //enum PACKAGE_POS=SIZE_POS+uint.sizeof;
            immutable(ubyte[]) data;
            immutable(Section) section;
            //immutable uint begin_index;
            // immutable uint size;
            // @property pure const {
            //     Section section() {
            //         return cast(Section)data[0];
            //     }
            // }

            this(immutable(ubyte[]) data) pure {
                section=cast(Section)data[0];
                size_t index=Section.sizeof;
                size_t u32_size;
                const size=u32(data[index..$], u32_size);
                index+=u32_size;
                // //const total_size=Section.sizeof+u32_size+size;
                // debug {
                //     writefln("data=%s", data[0..index+size]);
                //     writefln(":: %s index=%d u32_size=%d size=%d", section, index, u32_size, size);
                // }

                this.data=data[index..index+size];
            }


//             protected template GetSector(Section S, EList...) {
// //                static foreach(E; EnumMembers!Section) {
//                 switch (S) {
//                     case Section.Type:
//                         alias GetSector=Type;
//                     default:
//                         alias GetSector=Type;

//                 }
//             }

            alias Sections=AliasSeq!(
                Custom,
                Type,
                Import,
                Function,
                Table,
                Memory,
                Global,
                Export,
                Start,
                Element,
                Code);

            auto sec(Section S)()
                in {
                    assert(S is section);
                }
            do {
                alias T=Sections[S];
                return T(data);
            }

            struct VectorRange(ModuleSection, Element) {
                ModuleSection owner;
                protected size_t pos;
                protected uint index;
                this(ModuleSection owner)  {
                    this.owner=owner;
                }

                @property Element front() const {
                    return Element(owner.data[pos..$]);
                }

                @property bool empty() const pure nothrow {
                    return index>=owner.length;
                }

                @property void popFront() {
                    pos+=front.size;
                    index++;
                }
            }

            struct Custom {
                immutable(char[]) name;
                immutable(ubyte[]) bytes;
                this(immutable(ubyte[]) data) {
                    size_t index;
                    size_t bytes_size;
                    name=Vector!char(data[index..$], bytes_size);
                    index+=bytes_size;
                    bytes=Vector!ubyte(data[index..$], bytes_size);
                }
            }

            struct FuncType {
                immutable(Types[]) params;
                immutable(Types[]) returns;
                immutable(size_t) size;
                this(immutable(ubyte[]) data) {
                    size_t index=IR.sizeof;
                    size_t bytes_size;
                    params=Vector!Types(data[index..$], bytes_size);
                    index+=bytes_size;
                    returns=Vector!Types(data[index..$], bytes_size);
                    index+=bytes_size;
                    size=index;
                }
            }

            struct Type {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    length=u32(data[index..$], u32_size);
                    index+=u32_size;
                    this.data=data[index..$];
                }

                alias FuncRange=VectorRange!(Type, FuncType);

                FuncRange opSlice() {
                    return FuncRange(this);
                }
            }

            struct ImportType {
                immutable(char[]) mod;
                immutable(char[]) name;
                immutable(IndexType) desc;
                immutable(size_t) size;
//                immutable(
                this(immutable(ubyte[]) data) {
                    size_t index;//=IR.sizeof;
                    size_t bytes_size;
                    mod=Vector!char(data[index..$], bytes_size);
                    index+=bytes_size;
                    name=Vector!char(data[index..$], bytes_size);
                    index+=bytes_size;
                    desc=cast(IndexType)data[index];
                    size=index+1;
                }
            }

            struct Import {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    length=u32(data[index..$], u32_size);
                    index+=u32_size;
                    this.data=data[index..$];
                }

                alias ImportRange=VectorRange!(Import, ImportType);

                ImportRange opSlice() {
                    return ImportRange(this);
                }
            }


            struct Index {
                immutable(uint) value;
                immutable(size_t) size;
//                immutable(
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    value=u32(data[index..$], u32_size);
                    index+=u32_size;
                    size=index;
                }
            }

            struct Function {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    length=u32(data[index..$], u32_size);
                    index+=u32_size;
                    this.data=data[index..$];
                }

                alias FunctionRange=VectorRange!(Function, Index);

                FunctionRange opSlice() {
                    return FunctionRange(this);
                }
            }

            struct TableType {
                immutable(uint) begin;
                immutable(uint) end;
                immutable(size_t) size;
//                immutable(
                this(immutable(ubyte[]) data) {
                    check(data[0] == Types.FUNCREF,
                        format("Wrong element type 0x%02X expected %s=0x%02X", data[0], Types.FUNCREF, Types.FUNCREF));
                    size_t index=Types.sizeof; //=Section.sizeof;
                    const ltype=cast(Limits)data[index];
                    index+=Limits.sizeof;
                    size_t u32_size;
                    begin=u32(data[index..$], u32_size);
                    index+=u32_size;
                    uint _end;
                    if (ltype==Limits.LOWER) {
                        _end=uint.max;
                    }
                    else if (ltype==Limits.RANGE) {
                        _end=u32(data[index..$], u32_size);
                        index+=u32_size;
                    }
                    else {
                        check(0,
                            format("Bad Limits type 0x%02X in table", ltype));
                    }
                    _end=end;
                    // final switch(ltype) {
                    // case Limits.LOWER:
                    //     _end=uint.max;
                    //     break;
                    // case Limits.RANGE:
                    //     _end=u32(data[index..$], u32_size);
                    //     index+=u32_size;
                    //     break;
                    // }
                    //end=_end;
                    size=index;
                }
            }

            struct Table {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    length=u32(data[index..$], u32_size);
                    index+=u32_size;
                    this.data=data[index..$];
                }

                alias TableRange=VectorRange!(Table, TableType);

                TableRange opSlice() {
                    return TableRange(this);
                }

            }

            struct MemoryType {
                immutable(uint) begin;
                immutable(uint) end;
                immutable(size_t) size;
//                immutable(
                this(immutable(ubyte[]) data) {
                    // check(data[0] == Types.FUNCREF,
                    //     format("Wrong element type 0x%02X expected %s=0x%02X", data[0], Types.FUNCREF, Types.FUNCREF));
                    size_t index; //=Types.sizeof; //=Section.sizeof;
                    const ltype=cast(Limits)data[index];
                    index+=Limits.sizeof;
                    size_t u32_size;
                    begin=u32(data[index..$], u32_size);
                    index+=u32_size;
                    uint _end;
                    if (ltype==Limits.LOWER) {
                        _end=uint.max;
                    }
                    else if (ltype==Limits.RANGE) {
                        _end=u32(data[index..$], u32_size);
                        index+=u32_size;
                    }
                    else {
                        check(0,
                            format("Bad Limits type 0x%02X in table", ltype));
                    }
                    end=_end;
                    size=index;
                }
            }

            struct Memory {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    length=u32(data[index..$], u32_size);
                    index+=u32_size;
                    this.data=data[index..$];
                }

                alias MemoryRange=VectorRange!(Memory, MemoryType);

                MemoryRange opSlice() {
                    return MemoryRange(this);
                }
            }

            struct GlobalType {
                immutable(Types) valtype;
                immutable(Mutable) mut;
                immutable(size_t) size;
//                immutable(
                this(immutable(ubyte[]) data) {
                    valtype=cast(Types)data[0];
                    mut=cast(Mutable)data[Types.sizeof];
                    size=Types.sizeof+Mutable.sizeof;
                }
            }
            // struct Memory {
            // }

            struct Global {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    length=u32(data[index..$], u32_size);
                    index+=u32_size;
                    this.data=data[index..$];
                }

                alias GlobalRange=VectorRange!(Global, GlobalType);

                GlobalRange opSlice() {
                    return GlobalRange(this);
                }
            }

            struct ExportType {
                immutable(char[]) name;
                immutable(IndexType) desc;
                immutable(size_t) size;
//                immutable(
                this(immutable(ubyte[]) data) {
                    size_t index;//=IR.sizeof;
                    size_t bytes_size;
                    name=Vector!char(data[index..$], bytes_size);
                    index+=bytes_size;
                    desc=cast(IndexType)data[index];
                    size=index+1;
                }
            }

            struct Export {
                immutable uint length;
                immutable(ubyte[]) data;
                this(immutable(ubyte[]) data) {
                    size_t index; //=Section.sizeof;
                    size_t u32_size;
                    length=u32(data[index..$], u32_size);
                    index+=u32_size;
                    this.data=data[index..$];
                }

                alias ExportRange=VectorRange!(Export, ExportType);

                ExportRange opSlice() {
                    return ExportRange(this);
                }

            }

            struct Start {
                immutable(uint) idx;
                this(immutable(ubyte[]) data) {
                    size_t u32_size;
                    idx=u32(data, u32_size);
                }
            }



            version(none)
            struct ElementType {
                immutable(char[])    tableidx;
                immutable(IndexType) expr;
                immutable(Types[])   funcs;
//                immutable(
                this(immutable(ubyte[]) data) {
                    size_t index;//=IR.sizeof;
                    size_t bytes_size;
                    name=Vector!char(data[index..$], bytes_size);
                    index+=bytes_size;
                    desc=cast(IndexType)data[index];
                    size=index+1;
                }
            }

            struct Element {
            }

            struct Block {
                immutable(ubyte[]) data;
                //immutable(size_t) size;
                this(immutable(ubyte[]) data) {
                    size_t index;
                    while(index < data.length) {

                    }
                }
            }

            struct WasmArg {
                protected Types type;
                union {
                    @(Types.I32) int i32;
                    @(Types.I64) long i64;
                    @(Types.F32) float f32;
                    @(Types.F64) double f64;
                }
                void opAssign(T)(T x) {
                    alias BaseT=Unqual!T;
                    static if (is(BaseT == int) && is(BaseT == uint)) {
                        type=Types.I32;
                        i32=cast(int)x;
                    }
                    else static if (is(BaseT == long) && is(BaseT == ulong)) {
                        type=Types.I64;
                        i64=cast(long)x;
                    }
                    else static if (is(BaseT == float)) {
                        type=Types.F32;
                        f32=x;
                    }
                    else static if (is(BaseT == double)) {
                        type=Types.F64;
                        f64=x;
                    }
                }

                T get(T)() const pure nothrow {
                    alias BaseT=Unqual!T;
                    static if (is(BaseT == int)  && is(BaseT == uint)) {
                        check(type is Types.I32, format("Wrong to type %s execpted %s", type, Types.I32));
                        return cast(T)i32;
                    }
                    else static if (is(BaseT == long) && is(BaseT == ulong)) {
                        check(type is Types.I64, format("Wrong to type %s execpted %s", type, Types.I64));
                        return cast(T)i64;
                    }
                    else static if (is(BaseT == float)) {
                        check(type is Types.F32, format("Wrong to type %s execpted %s", type, Types.F32));
                        return f32;
                    }
                    else static if (is(BaseT == double)) {
                        check(type is Types.F64, format("Wrong to type %s execpted %s", type, Types.F64));
                        return f64;
                    }
                }
            }

            struct CodeRange {
                immutable(ubyte[]) data;
                protected {
                    size_t index;
                    WasmArg[2] _args;
                }

                //immutable(size_t) size;
                this(immutable(ubyte[]) data) {
                    this.data=data;
                }

                @property IR front() const pure {
                    return cast(IR)data[index];
                }

                @property bool empty() const pure nothrow {
                    return index >= data.length;
                }

                @property void popFront() {
                    void set(ref WasmArg arg, const Types type) {
//                        const type=cast(Types)data[index];
                        size_t leb128_size;
                        index++;
                        with(Types) {
                            switch(type) {
                            case I32:
                                arg=u32(data[index..$], leb128_size);
                                break;
                            case I64:
                                arg=u64(data[index..$], leb128_size);
                                break;
                            case F32:
                                arg=data.binpeek!(float, Endian.littleEndian)(&index);
                                break;
                            case F64:
                                arg=data.binpeek!(double, Endian.littleEndian)(&index);
                                break;
                            default:
                                check(0, format("Assembler argument type not vaild as an argument %s", type));
                            }
                        }
                    }
                    const ir=front;
                    const instr=instrTable[ir];
                    index++;
                    with(IRType) {
                        final switch(instr.irtype) {
                        case CODE:
                            break;
                        case BLOCK:
                            break;
                        case BRANCH:
                            break;
                        case BRANCH_TABLE:
                            break;
                        case CALL:
                            break;
                        case CALL_INDIRECT:
                            break;
                        case LOCAL:
                            break;
                        case GLOBAL:
                            break;
                        case MEMORY:
                            break;
                        case MEMOP:
                            break;
                        case CONST:
                            const type=cast(Types)data[index];
                            set(_args[0], type);
                            break;
                        case END:
                            break;
                        }
                    }
                }

            }

            struct Code {
            }

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
        writeln("WAVM Started");
        {
            //string filename="../tests/simple/simple.wasm";
            //string filename="../tests/wasm/custom_1.wasm";
            //string filename="../tests/wasm/func_2.wasm";
            //string filename="../tests/wasm/table_copy_2.wasm"; //../tests/wasm/func_2.wasm";
//            string filename="../tests/wasm/memory_4.wasm"; //../tests/wasm/func_2.wasm";
            //string filename="../tests/wasm/global_1.wasm";
            string filename="../tests/wasm/start_4.wasm";
            immutable code=fread(filename);
            auto wasm=Wasm(code);
            auto range=wasm[];
            writefln("WasmRange %s %d %d", range.empty, wasm.data.length, code.length);
            foreach(a; range) {

                writefln("%s length=%d data=%s", a.section, a.data.length, a.data);
                if (a.section == Section.TYPE) {
                    auto _type=a.sec!(Section.TYPE);
//                    writefln("Function types %s", _type.func_types);
                    writefln("Type types length %d %s", _type.length, _type[]);
                }
                else if (a.section == Section.IMPORT) {
                    auto _import=a.sec!(Section.IMPORT);
//                    writefln("Function types %s", _type.func_types);
                    //   writefln("Import types length %d %s", _import.length, _import[]);
                }
                else if (a.section == Section.EXPORT) {
                    auto _export=a.sec!(Section.EXPORT);
//                    writefln("Function types %s", _type.func_types);
                    // writefln("Export types length %d %s", _export.length, _export[]);
                }
                else if (a.section == Section.FUNCTION) {
                    auto _function=a.sec!(Section.FUNCTION);
//                    writefln("Function types %s", _type.func_types);
                    writefln("Function types length %d %s", _function.length, _function[]);
                }
                else if (a.section == Section.TABLE) {
                    auto _table=a.sec!(Section.TABLE);
//                    writefln("Function types %s", _type.func_types);
                    writefln("Table types length %d %s", _table.length, _table[]);
//                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.MEMORY) {
                    auto _memory=a.sec!(Section.MEMORY);
//                    writefln("Function types %s", _type.func_types);
                    writefln("Memory types length %d %s", _memory.length, _memory[]);
//                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.GLOBAL) {
                    auto _global=a.sec!(Section.GLOBAL);
//                    writefln("Function types %s", _type.func_types);
                    writefln("Global types length %d %s", _global.length, _global[]);
//                    writefln("Table types %s", _table);
                }
                else if (a.section == Section.START) {
                    auto _start=a.sec!(Section.START);
//                    writefln("Function types %s", _type.func_types);
                    writefln("Start types %s", _start);
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
