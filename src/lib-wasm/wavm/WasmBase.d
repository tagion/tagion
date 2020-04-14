module wavm.WasmBase;

import std.traits : EnumMembers;
import std.typecons : Tuple;
import std.format;
import std.uni : toLower;
import std.conv : to;

//import wavm.LEB128;
import LEB128=wavm.LEB128;


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
    uint pops; // Number of pops from the stack
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
            I32_EQZ             : Instr("i32.eqz", 1, IRType.CODE, 1),
            I32_EQ              : Instr("i32.eq", 1, IRType.CODE, 1),
            I32_NE              : Instr("i32.ne", 1, IRType.CODE, 1),
            I32_LT_S            : Instr("i32.lt_s", 1, IRType.CODE, 2),
            I32_LT_U            : Instr("i32.lt_u", 1, IRType.CODE, 2),
            I32_GT_S            : Instr("i32.gt_s", 1, IRType.CODE, 2),
            I32_GT_U            : Instr("i32.gt_u", 1, IRType.CODE, 2),
            I32_LE_S            : Instr("i32.le_s", 1, IRType.CODE, 2),
            I32_LE_U            : Instr("i32.le_u", 1, IRType.CODE, 2),
            I32_GE_S            : Instr("i32.ge_s", 1, IRType.CODE, 2),
            I32_GE_U            : Instr("i32.ge_u", 1, IRType.CODE, 2),

            I64_EQZ             : Instr("i64.eqz", 1, IRType.CODE, 1),
            I64_EQ              : Instr("i64.eq", 1, IRType.CODE, 1),
            I64_NE              : Instr("i64.ne", 1, IRType.CODE, 1),
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
    INFINITE = 0x00, ///  n:u32       ⇒ {min n, max ε}
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

@safe
static string typesName(const Types type) pure {
    import std.uni : toLower;
    import std.conv : to;
    final switch(type) {
        foreach(E; EnumMembers!Types) {
        case E: return toLower(E.to!string);
        }
    }
}

enum IndexType : ubyte {
    FUNC =   0x00, /// func x:typeidx
        TABLE =     0x01, /// func  tt:tabletype
        MEMORY =       0x02, /// mem mt:memtype
        GLOBAL =    0x03, /// global gt:globaltype
        }

@safe
static string indexName(const IndexType idx) pure {
    import std.uni : toLower;
    import std.conv : to;
    final switch(idx) {
        foreach(E; EnumMembers!IndexType) {
        case E: return toLower(E.to!string);
        }
    }
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

T decode(T)(immutable(ubyte[]) data, ref size_t index) pure {
    size_t byte_size;
    scope(exit) {
        index+=byte_size;
    }
    return LEB128.decode!T(data[index..$], byte_size);
}

alias u32=decode!uint;
alias u64=decode!ulong;
alias i32=decode!int;
alias i64=decode!long;

static string secname(immutable Section s) {
    import std.exception : assumeUnique;
    return assumeUnique(format("%s_sec", toLower(s.to!string)));
}

alias ModuleT(SectionType)=Tuple!(
    const(SectionType.Custom)*,   secname(Section.CUSTOM),
    const(SectionType.Type)*,     secname(Section.TYPE),
    const(SectionType.Import)*,   secname(Section.IMPORT),
    const(SectionType.Function)*, secname(Section.FUNCTION),
    const(SectionType.Table)*,    secname(Section.TABLE),
    const(SectionType.Memory)*,   secname(Section.MEMORY),
    const(SectionType.Global)*,   secname(Section.GLOBAL),
    const(SectionType.Export)*,   secname(Section.EXPORT),
    const(SectionType.Start)*,    secname(Section.START),
    const(SectionType.Element)*,  secname(Section.ELEMENT),
    const(SectionType.Code)*,     secname(Section.CODE),
    const(SectionType.Data)*,     secname(Section.DATA),
    );


interface InterfaceModuleT(T) {
    void custom_sec(ref scope const(T) mod);
    void type_sec(ref scope const(T) mod);
    void import_sec(ref scope const(T) mod);
    void function_sec(ref scope const(T) mod);
    void table_sec(ref scope const(T) mod);
    void memory_sec(ref scope const(T) mod);
    void global_sec(ref scope const(T) mod);
    void export_sec(ref scope const(T) mod);
    void start_sec(ref scope const(T) mod);
    void element_sec(ref scope const(T) mod);
    void code_sec(ref scope const(T) mod);
    void data_sec(ref scope const(T) mod);
}
