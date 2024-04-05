// WebAssembly C API

module tagion.wasmer.c.wasm;

import tagion.wasmer.c.wasm_types;

extern (C):
nothrow:
@nogc:

///////////////////////////////////////////////////////////////////////////////
// Auxiliaries

// Machine types

void assertions ();

alias byte_t = char;
alias float32_t = float;
alias float64_t = double;

// Ownership

// The qualifier `own` is used to indicate ownership of data in this API.
// It is intended to be interpreted similar to a `const` qualifier:
//
// - `own wasm_xxx_t*` owns the pointed-to data
// - `own wasm_xxx_t` distributes to all fields of a struct or union `xxx`
// - `own wasm_xxx_vec_t` owns the vector as well as its elements(!)
// - an `own` function parameter passes ownership from caller to callee
// - an `own` function result passes ownership from callee to caller
// - an exception are `own` pointer parameters named `out`, which are copy-back
//   output parameters passing back ownership from callee to caller
//
// Own data is created by `wasm_xxx_new` functions and some others.
// It must be released with the corresponding `wasm_xxx_delete` function.
//
// Deleting a reference does not necessarily delete the underlying object,
// it merely indicates that this owner no longer uses it.
//
// For vectors, `const wasm_xxx_vec_t` is used informally to indicate that
// neither the vector nor its elements should be modified.
// TODO: introduce proper `wasm_xxx_const_vec_t`?

// Vectors

// Byte vectors

alias wasm_byte_t = char;

struct wasm_byte_vec_t
{
    size_t size;
    wasm_byte_t* data;
}

void wasm_byte_vec_new_empty (wasm_byte_vec_t* out_);
void wasm_byte_vec_new_uninitialized (wasm_byte_vec_t* out_, size_t);
void wasm_byte_vec_new (wasm_byte_vec_t* out_, size_t, const(wasm_byte_t)*);
void wasm_byte_vec_copy (wasm_byte_vec_t* out_, const(wasm_byte_vec_t)*);
void wasm_byte_vec_delete (wasm_byte_vec_t*);

alias wasm_name_t = wasm_byte_vec_t;

alias wasm_name = wasm_byte_vec_t;
alias wasm_name_new = wasm_byte_vec_new;
alias wasm_name_new_empty = wasm_byte_vec_new_empty;
alias wasm_name_new_new_uninitialized = wasm_byte_vec_new_uninitialized;
alias wasm_name_copy = wasm_byte_vec_copy;
alias wasm_name_delete = wasm_byte_vec_delete;

void wasm_name_new_from_string (wasm_name_t* out_, const(char)* s);

void wasm_name_new_from_string_nt (wasm_name_t* out_, const(char)* s);

///////////////////////////////////////////////////////////////////////////////
// Runtime Environment

// Configuration

struct wasm_config_t;
void wasm_config_delete (wasm_config_t*);

wasm_config_t* wasm_config_new ();

// Embedders may provide custom functions for manipulating configs.

// Engine

struct wasm_engine_t;
void wasm_engine_delete (wasm_engine_t*);

// During testing, we use a custom implementation of wasm_engine_new

wasm_engine_t* wasm_engine_new ();

wasm_engine_t* wasm_engine_new_with_config (wasm_config_t*);

// Store

struct wasm_store_t;
void wasm_store_delete (wasm_store_t*);

wasm_store_t* wasm_store_new (wasm_engine_t*);

///////////////////////////////////////////////////////////////////////////////
// Type Representations

// Type attributes

alias wasm_mutability_t = ubyte;

enum wasm_mutability_enum
{
    WASM_CONST = 0,
    WASM_VAR = 1
}

struct wasm_limits_t
{
    uint min;
    uint max;
}

extern __gshared const uint wasm_limits_max_default;

// Generic

// Value Types

struct wasm_valtype_t;
void wasm_valtype_delete (wasm_valtype_t*);

struct wasm_valtype_vec_t
{
    size_t size;
    wasm_valtype_t** data;
}

void wasm_valtype_vec_new_empty (wasm_valtype_vec_t* out_);
void wasm_valtype_vec_new_uninitialized (wasm_valtype_vec_t* out_, size_t);
void wasm_valtype_vec_new (wasm_valtype_vec_t* out_, size_t, const(wasm_valtype_t*)*);
void wasm_valtype_vec_copy (wasm_valtype_vec_t* out_, const(wasm_valtype_vec_t)*);
void wasm_valtype_vec_delete (wasm_valtype_vec_t*);
wasm_valtype_t* wasm_valtype_copy (wasm_valtype_t*);

alias wasm_valkind_t = ubyte;

enum wasm_valkind_enum
{
    WASM_I32 = 0,
    WASM_I64 = 1,
    WASM_F32 = 2,
    WASM_F64 = 3,
    WASM_ANYREF = 128,
    WASM_FUNCREF = 129
}

wasm_valtype_t* wasm_valtype_new (wasm_valkind_t);

wasm_valkind_t wasm_valtype_kind (const(wasm_valtype_t)*);

bool wasm_valkind_is_num (wasm_valkind_t k);
bool wasm_valkind_is_ref (wasm_valkind_t k);

bool wasm_valtype_is_num (const(wasm_valtype_t)* t);
bool wasm_valtype_is_ref (const(wasm_valtype_t)* t);

// Function Types

struct wasm_functype_t;
void wasm_functype_delete (wasm_functype_t*);

struct wasm_functype_vec_t
{
    size_t size;
    wasm_functype_t** data;
}

void wasm_functype_vec_new_empty (wasm_functype_vec_t* out_);
void wasm_functype_vec_new_uninitialized (wasm_functype_vec_t* out_, size_t);
void wasm_functype_vec_new (wasm_functype_vec_t* out_, size_t, const(wasm_functype_t*)*);
void wasm_functype_vec_copy (wasm_functype_vec_t* out_, const(wasm_functype_vec_t)*);
void wasm_functype_vec_delete (wasm_functype_vec_t*);
wasm_functype_t* wasm_functype_copy (wasm_functype_t*);

wasm_functype_t* wasm_functype_new (
    wasm_valtype_vec_t* params,
    wasm_valtype_vec_t* results);

const(wasm_valtype_vec_t)* wasm_functype_params (const(wasm_functype_t)*);
const(wasm_valtype_vec_t)* wasm_functype_results (const(wasm_functype_t)*);

// Global Types

struct wasm_globaltype_t;
void wasm_globaltype_delete (wasm_globaltype_t*);

struct wasm_globaltype_vec_t
{
    size_t size;
    wasm_globaltype_t** data;
}

void wasm_globaltype_vec_new_empty (wasm_globaltype_vec_t* out_);
void wasm_globaltype_vec_new_uninitialized (wasm_globaltype_vec_t* out_, size_t);
void wasm_globaltype_vec_new (wasm_globaltype_vec_t* out_, size_t, const(wasm_globaltype_t*)*);
void wasm_globaltype_vec_copy (wasm_globaltype_vec_t* out_, const(wasm_globaltype_vec_t)*);
void wasm_globaltype_vec_delete (wasm_globaltype_vec_t*);
wasm_globaltype_t* wasm_globaltype_copy (wasm_globaltype_t*);

wasm_globaltype_t* wasm_globaltype_new (wasm_valtype_t*, wasm_mutability_t);

const(wasm_valtype_t)* wasm_globaltype_content (const(wasm_globaltype_t)*);
wasm_mutability_t wasm_globaltype_mutability (const(wasm_globaltype_t)*);

// Table Types

struct wasm_tabletype_t;
void wasm_tabletype_delete (wasm_tabletype_t*);

struct wasm_tabletype_vec_t
{
    size_t size;
    wasm_tabletype_t** data;
}

void wasm_tabletype_vec_new_empty (wasm_tabletype_vec_t* out_);
void wasm_tabletype_vec_new_uninitialized (wasm_tabletype_vec_t* out_, size_t);
void wasm_tabletype_vec_new (wasm_tabletype_vec_t* out_, size_t, const(wasm_tabletype_t*)*);
void wasm_tabletype_vec_copy (wasm_tabletype_vec_t* out_, const(wasm_tabletype_vec_t)*);
void wasm_tabletype_vec_delete (wasm_tabletype_vec_t*);
wasm_tabletype_t* wasm_tabletype_copy (wasm_tabletype_t*);

wasm_tabletype_t* wasm_tabletype_new (wasm_valtype_t*, const(wasm_limits_t)*);

const(wasm_valtype_t)* wasm_tabletype_element (const(wasm_tabletype_t)*);
const(wasm_limits_t)* wasm_tabletype_limits (const(wasm_tabletype_t)*);

// Memory Types

struct wasm_memorytype_t;
void wasm_memorytype_delete (wasm_memorytype_t*);

struct wasm_memorytype_vec_t
{
    size_t size;
    wasm_memorytype_t** data;
}

void wasm_memorytype_vec_new_empty (wasm_memorytype_vec_t* out_);
void wasm_memorytype_vec_new_uninitialized (wasm_memorytype_vec_t* out_, size_t);
void wasm_memorytype_vec_new (wasm_memorytype_vec_t* out_, size_t, const(wasm_memorytype_t*)*);
void wasm_memorytype_vec_copy (wasm_memorytype_vec_t* out_, const(wasm_memorytype_vec_t)*);
void wasm_memorytype_vec_delete (wasm_memorytype_vec_t*);
wasm_memorytype_t* wasm_memorytype_copy (wasm_memorytype_t*);

wasm_memorytype_t* wasm_memorytype_new (const(wasm_limits_t)*);

const(wasm_limits_t)* wasm_memorytype_limits (const(wasm_memorytype_t)*);

// Extern Types

struct wasm_externtype_t;
void wasm_externtype_delete (wasm_externtype_t*);

struct wasm_externtype_vec_t
{
    size_t size;
    wasm_externtype_t** data;
}

void wasm_externtype_vec_new_empty (wasm_externtype_vec_t* out_);
void wasm_externtype_vec_new_uninitialized (wasm_externtype_vec_t* out_, size_t);
void wasm_externtype_vec_new (wasm_externtype_vec_t* out_, size_t, const(wasm_externtype_t*)*);
void wasm_externtype_vec_copy (wasm_externtype_vec_t* out_, const(wasm_externtype_vec_t)*);
void wasm_externtype_vec_delete (wasm_externtype_vec_t*);
wasm_externtype_t* wasm_externtype_copy (wasm_externtype_t*);

alias wasm_externkind_t = ubyte;

enum wasm_externkind_enum
{
    WASM_EXTERN_FUNC = 0,
    WASM_EXTERN_GLOBAL = 1,
    WASM_EXTERN_TABLE = 2,
    WASM_EXTERN_MEMORY = 3
}

wasm_externkind_t wasm_externtype_kind (const(wasm_externtype_t)*);

wasm_externtype_t* wasm_functype_as_externtype (wasm_functype_t*);
wasm_externtype_t* wasm_globaltype_as_externtype (wasm_globaltype_t*);
wasm_externtype_t* wasm_tabletype_as_externtype (wasm_tabletype_t*);
wasm_externtype_t* wasm_memorytype_as_externtype (wasm_memorytype_t*);

wasm_functype_t* wasm_externtype_as_functype (wasm_externtype_t*);
wasm_globaltype_t* wasm_externtype_as_globaltype (wasm_externtype_t*);
wasm_tabletype_t* wasm_externtype_as_tabletype (wasm_externtype_t*);
wasm_memorytype_t* wasm_externtype_as_memorytype (wasm_externtype_t*);

const(wasm_externtype_t)* wasm_functype_as_externtype_const (const(wasm_functype_t)*);
const(wasm_externtype_t)* wasm_globaltype_as_externtype_const (const(wasm_globaltype_t)*);
const(wasm_externtype_t)* wasm_tabletype_as_externtype_const (const(wasm_tabletype_t)*);
const(wasm_externtype_t)* wasm_memorytype_as_externtype_const (const(wasm_memorytype_t)*);

const(wasm_functype_t)* wasm_externtype_as_functype_const (const(wasm_externtype_t)*);
const(wasm_globaltype_t)* wasm_externtype_as_globaltype_const (const(wasm_externtype_t)*);
const(wasm_tabletype_t)* wasm_externtype_as_tabletype_const (const(wasm_externtype_t)*);
const(wasm_memorytype_t)* wasm_externtype_as_memorytype_const (const(wasm_externtype_t)*);

// Import Types

struct wasm_importtype_t;
void wasm_importtype_delete (wasm_importtype_t*);

struct wasm_importtype_vec_t
{
    size_t size;
    wasm_importtype_t** data;
}

void wasm_importtype_vec_new_empty (wasm_importtype_vec_t* out_);
void wasm_importtype_vec_new_uninitialized (wasm_importtype_vec_t* out_, size_t);
void wasm_importtype_vec_new (wasm_importtype_vec_t* out_, size_t, const(wasm_importtype_t*)*);
void wasm_importtype_vec_copy (wasm_importtype_vec_t* out_, const(wasm_importtype_vec_t)*);
void wasm_importtype_vec_delete (wasm_importtype_vec_t*);
wasm_importtype_t* wasm_importtype_copy (wasm_importtype_t*);

wasm_importtype_t* wasm_importtype_new (
    wasm_name_t* module_,
    wasm_name_t* name,
    wasm_externtype_t*);

const(wasm_name_t)* wasm_importtype_module (const(wasm_importtype_t)*);
const(wasm_name_t)* wasm_importtype_name (const(wasm_importtype_t)*);
const(wasm_externtype_t)* wasm_importtype_type (const(wasm_importtype_t)*);

// Export Types

struct wasm_exporttype_t;
void wasm_exporttype_delete (wasm_exporttype_t*);

struct wasm_exporttype_vec_t
{
    size_t size;
    wasm_exporttype_t** data;
}

void wasm_exporttype_vec_new_empty (wasm_exporttype_vec_t* out_);
void wasm_exporttype_vec_new_uninitialized (wasm_exporttype_vec_t* out_, size_t);
void wasm_exporttype_vec_new (wasm_exporttype_vec_t* out_, size_t, const(wasm_exporttype_t*)*);
void wasm_exporttype_vec_copy (wasm_exporttype_vec_t* out_, const(wasm_exporttype_vec_t)*);
void wasm_exporttype_vec_delete (wasm_exporttype_vec_t*);
wasm_exporttype_t* wasm_exporttype_copy (wasm_exporttype_t*);

wasm_exporttype_t* wasm_exporttype_new (wasm_name_t*, wasm_externtype_t*);

const(wasm_name_t)* wasm_exporttype_name (const(wasm_exporttype_t)*);
const(wasm_externtype_t)* wasm_exporttype_type (const(wasm_exporttype_t)*);

///////////////////////////////////////////////////////////////////////////////
// Runtime Objects

// Values

struct wasm_ref_t;

version(none) struct wasm_val_t
{
    wasm_valkind_t kind;

    union _Anonymous_0
    {
        int i32;
        long i64;
        float32_t f32;
        float64_t f64;
        wasm_ref_t* ref_;
    }

    _Anonymous_0 of;
}

void wasm_val_delete (wasm_val_t* v);
void wasm_val_copy (wasm_val_t* out_, const(wasm_val_t)*);

version(none) struct wasm_val_vec_t
{
    size_t size;
    wasm_val_t* data;
}

void wasm_val_vec_new_empty (wasm_val_vec_t* out_);
void wasm_val_vec_new_uninitialized (wasm_val_vec_t* out_, size_t);
void wasm_val_vec_new (wasm_val_vec_t* out_, size_t, const(wasm_val_t)*);
void wasm_val_vec_copy (wasm_val_vec_t* out_, const(wasm_val_vec_t)*);
void wasm_val_vec_delete (wasm_val_vec_t*);

// References

void wasm_ref_delete (wasm_ref_t*);
wasm_ref_t* wasm_ref_copy (const(wasm_ref_t)*);
bool wasm_ref_same (const(wasm_ref_t)*, const(wasm_ref_t)*);
void* wasm_ref_get_host_info (const(wasm_ref_t)*);
void wasm_ref_set_host_info (wasm_ref_t*, void*);
void wasm_ref_set_host_info_with_finalizer (wasm_ref_t*, void*, void function (void*));

// Frames

struct wasm_frame_t;
void wasm_frame_delete (wasm_frame_t*);

struct wasm_frame_vec_t
{
    size_t size;
    wasm_frame_t** data;
}

void wasm_frame_vec_new_empty (wasm_frame_vec_t* out_);
void wasm_frame_vec_new_uninitialized (wasm_frame_vec_t* out_, size_t);
void wasm_frame_vec_new (wasm_frame_vec_t* out_, size_t, const(wasm_frame_t*)*);
void wasm_frame_vec_copy (wasm_frame_vec_t* out_, const(wasm_frame_vec_t)*);
void wasm_frame_vec_delete (wasm_frame_vec_t*);
wasm_frame_t* wasm_frame_copy (const(wasm_frame_t)*);

struct wasm_instance_t;
wasm_instance_t* wasm_frame_instance (const(wasm_frame_t)*);
uint wasm_frame_func_index (const(wasm_frame_t)*);
size_t wasm_frame_func_offset (const(wasm_frame_t)*);
size_t wasm_frame_module_offset (const(wasm_frame_t)*);

// Traps

alias wasm_message_t = wasm_byte_vec_t; // null terminated

struct wasm_trap_t;
void wasm_trap_delete (wasm_trap_t*);
wasm_trap_t* wasm_trap_copy (const(wasm_trap_t)*);
bool wasm_trap_same (const(wasm_trap_t)*, const(wasm_trap_t)*);
void* wasm_trap_get_host_info (const(wasm_trap_t)*);
void wasm_trap_set_host_info (wasm_trap_t*, void*);
void wasm_trap_set_host_info_with_finalizer (wasm_trap_t*, void*, void function (void*));
wasm_ref_t* wasm_trap_as_ref (wasm_trap_t*);
wasm_trap_t* wasm_ref_as_trap (wasm_ref_t*);
const(wasm_ref_t)* wasm_trap_as_ref_const (const(wasm_trap_t)*);
const(wasm_trap_t)* wasm_ref_as_trap_const (const(wasm_ref_t)*);

wasm_trap_t* wasm_trap_new (wasm_store_t* store, const(wasm_message_t)*);

void wasm_trap_message (const(wasm_trap_t)*, wasm_message_t* out_);
wasm_frame_t* wasm_trap_origin (const(wasm_trap_t)*);
void wasm_trap_trace (const(wasm_trap_t)*, wasm_frame_vec_t* out_);

// Foreign Objects

struct wasm_foreign_t;
void wasm_foreign_delete (wasm_foreign_t*);
wasm_foreign_t* wasm_foreign_copy (const(wasm_foreign_t)*);
bool wasm_foreign_same (const(wasm_foreign_t)*, const(wasm_foreign_t)*);
void* wasm_foreign_get_host_info (const(wasm_foreign_t)*);
void wasm_foreign_set_host_info (wasm_foreign_t*, void*);
void wasm_foreign_set_host_info_with_finalizer (wasm_foreign_t*, void*, void function (void*));
wasm_ref_t* wasm_foreign_as_ref (wasm_foreign_t*);
wasm_foreign_t* wasm_ref_as_foreign (wasm_ref_t*);
const(wasm_ref_t)* wasm_foreign_as_ref_const (const(wasm_foreign_t)*);
const(wasm_foreign_t)* wasm_ref_as_foreign_const (const(wasm_ref_t)*);

wasm_foreign_t* wasm_foreign_new (wasm_store_t*);

// Modules

struct wasm_module_t;
void wasm_module_delete (wasm_module_t*);
wasm_module_t* wasm_module_copy (const(wasm_module_t)*);
bool wasm_module_same (const(wasm_module_t)*, const(wasm_module_t)*);
void* wasm_module_get_host_info (const(wasm_module_t)*);
void wasm_module_set_host_info (wasm_module_t*, void*);
void wasm_module_set_host_info_with_finalizer (wasm_module_t*, void*, void function (void*));
wasm_ref_t* wasm_module_as_ref (wasm_module_t*);
wasm_module_t* wasm_ref_as_module (wasm_ref_t*);
const(wasm_ref_t)* wasm_module_as_ref_const (const(wasm_module_t)*);
const(wasm_module_t)* wasm_ref_as_module_const (const(wasm_ref_t)*);
struct wasm_shared_module_t;
void wasm_shared_module_delete (wasm_shared_module_t*);
wasm_shared_module_t* wasm_module_share (const(wasm_module_t)*);
wasm_module_t* wasm_module_obtain (wasm_store_t*, const(wasm_shared_module_t)*);

wasm_module_t* wasm_module_new (wasm_store_t*, const(wasm_byte_vec_t)* binary);

bool wasm_module_validate (wasm_store_t*, const(wasm_byte_vec_t)* binary);

void wasm_module_imports (const(wasm_module_t)*, wasm_importtype_vec_t* out_);
void wasm_module_exports (const(wasm_module_t)*, wasm_exporttype_vec_t* out_);

void wasm_module_serialize (const(wasm_module_t)*, wasm_byte_vec_t* out_);
wasm_module_t* wasm_module_deserialize (wasm_store_t*, const(wasm_byte_vec_t)*);

// Function Instances

struct wasm_func_t;
void wasm_func_delete (wasm_func_t*);
wasm_func_t* wasm_func_copy (const(wasm_func_t)*);
bool wasm_func_same (const(wasm_func_t)*, const(wasm_func_t)*);
void* wasm_func_get_host_info (const(wasm_func_t)*);
void wasm_func_set_host_info (wasm_func_t*, void*);
void wasm_func_set_host_info_with_finalizer (wasm_func_t*, void*, void function (void*));
wasm_ref_t* wasm_func_as_ref (wasm_func_t*);
wasm_func_t* wasm_ref_as_func (wasm_ref_t*);
const(wasm_ref_t)* wasm_func_as_ref_const (const(wasm_func_t)*);
const(wasm_func_t)* wasm_ref_as_func_const (const(wasm_ref_t)*);

alias wasm_func_callback_t = wasm_trap_t* function (
    const(wasm_val_vec_t)* args,
    wasm_val_vec_t* results);
alias wasm_func_callback_with_env_t = wasm_trap_t* function (
    void* env,
    const(wasm_val_vec_t)* args,
    wasm_val_vec_t* results);

wasm_func_t* wasm_func_new (
    wasm_store_t*,
    const(wasm_functype_t)*,
    wasm_func_callback_t);
wasm_func_t* wasm_func_new_with_env (
    wasm_store_t*,
    const(wasm_functype_t)* type,
    wasm_func_callback_with_env_t,
    void* env,
    void function (void*) finalizer);

wasm_functype_t* wasm_func_type (const(wasm_func_t)*);
size_t wasm_func_param_arity (const(wasm_func_t)*);
size_t wasm_func_result_arity (const(wasm_func_t)*);

wasm_trap_t* wasm_func_call (
    const(wasm_func_t)*,
    const(wasm_val_vec_t)* args,
    wasm_val_vec_t* results);

// Global Instances

struct wasm_global_t;
void wasm_global_delete (wasm_global_t*);
wasm_global_t* wasm_global_copy (const(wasm_global_t)*);
bool wasm_global_same (const(wasm_global_t)*, const(wasm_global_t)*);
void* wasm_global_get_host_info (const(wasm_global_t)*);
void wasm_global_set_host_info (wasm_global_t*, void*);
void wasm_global_set_host_info_with_finalizer (wasm_global_t*, void*, void function (void*));
wasm_ref_t* wasm_global_as_ref (wasm_global_t*);
wasm_global_t* wasm_ref_as_global (wasm_ref_t*);
const(wasm_ref_t)* wasm_global_as_ref_const (const(wasm_global_t)*);
const(wasm_global_t)* wasm_ref_as_global_const (const(wasm_ref_t)*);

wasm_global_t* wasm_global_new (
    wasm_store_t*,
    const(wasm_globaltype_t)*,
    const(wasm_val_t)*);

wasm_globaltype_t* wasm_global_type (const(wasm_global_t)*);

void wasm_global_get (const(wasm_global_t)*, wasm_val_t* out_);
void wasm_global_set (wasm_global_t*, const(wasm_val_t)*);

// Table Instances

struct wasm_table_t;
void wasm_table_delete (wasm_table_t*);
wasm_table_t* wasm_table_copy (const(wasm_table_t)*);
bool wasm_table_same (const(wasm_table_t)*, const(wasm_table_t)*);
void* wasm_table_get_host_info (const(wasm_table_t)*);
void wasm_table_set_host_info (wasm_table_t*, void*);
void wasm_table_set_host_info_with_finalizer (wasm_table_t*, void*, void function (void*));
wasm_ref_t* wasm_table_as_ref (wasm_table_t*);
wasm_table_t* wasm_ref_as_table (wasm_ref_t*);
const(wasm_ref_t)* wasm_table_as_ref_const (const(wasm_table_t)*);
const(wasm_table_t)* wasm_ref_as_table_const (const(wasm_ref_t)*);

alias wasm_table_size_t = uint;

wasm_table_t* wasm_table_new (
    wasm_store_t*,
    const(wasm_tabletype_t)*,
    wasm_ref_t* init);

wasm_tabletype_t* wasm_table_type (const(wasm_table_t)*);

wasm_ref_t* wasm_table_get (const(wasm_table_t)*, wasm_table_size_t index);
bool wasm_table_set (wasm_table_t*, wasm_table_size_t index, wasm_ref_t*);

wasm_table_size_t wasm_table_size (const(wasm_table_t)*);
bool wasm_table_grow (wasm_table_t*, wasm_table_size_t delta, wasm_ref_t* init);

// Memory Instances

struct wasm_memory_t;
void wasm_memory_delete (wasm_memory_t*);
wasm_memory_t* wasm_memory_copy (const(wasm_memory_t)*);
bool wasm_memory_same (const(wasm_memory_t)*, const(wasm_memory_t)*);
void* wasm_memory_get_host_info (const(wasm_memory_t)*);
void wasm_memory_set_host_info (wasm_memory_t*, void*);
void wasm_memory_set_host_info_with_finalizer (wasm_memory_t*, void*, void function (void*));
wasm_ref_t* wasm_memory_as_ref (wasm_memory_t*);
wasm_memory_t* wasm_ref_as_memory (wasm_ref_t*);
const(wasm_ref_t)* wasm_memory_as_ref_const (const(wasm_memory_t)*);
const(wasm_memory_t)* wasm_ref_as_memory_const (const(wasm_ref_t)*);

alias wasm_memory_pages_t = uint;

extern __gshared const size_t MEMORY_PAGE_SIZE;

wasm_memory_t* wasm_memory_new (wasm_store_t*, const(wasm_memorytype_t)*);

wasm_memorytype_t* wasm_memory_type (const(wasm_memory_t)*);

byte_t* wasm_memory_data (wasm_memory_t*);
size_t wasm_memory_data_size (const(wasm_memory_t)*);

wasm_memory_pages_t wasm_memory_size (const(wasm_memory_t)*);
bool wasm_memory_grow (wasm_memory_t*, wasm_memory_pages_t delta);

// Externals

struct wasm_extern_t;
void wasm_extern_delete (wasm_extern_t*);
wasm_extern_t* wasm_extern_copy (const(wasm_extern_t)*);
bool wasm_extern_same (const(wasm_extern_t)*, const(wasm_extern_t)*);
void* wasm_extern_get_host_info (const(wasm_extern_t)*);
void wasm_extern_set_host_info (wasm_extern_t*, void*);
void wasm_extern_set_host_info_with_finalizer (wasm_extern_t*, void*, void function (void*));
wasm_ref_t* wasm_extern_as_ref (wasm_extern_t*);
wasm_extern_t* wasm_ref_as_extern (wasm_ref_t*);
const(wasm_ref_t)* wasm_extern_as_ref_const (const(wasm_extern_t)*);
const(wasm_extern_t)* wasm_ref_as_extern_const (const(wasm_ref_t)*);

struct wasm_extern_vec_t
{
    size_t size;
    wasm_extern_t** data;
}

void wasm_extern_vec_new_empty (wasm_extern_vec_t* out_);
void wasm_extern_vec_new_uninitialized (wasm_extern_vec_t* out_, size_t);
void wasm_extern_vec_new (wasm_extern_vec_t* out_, size_t, const(wasm_extern_t*)*);
void wasm_extern_vec_copy (wasm_extern_vec_t* out_, const(wasm_extern_vec_t)*);
void wasm_extern_vec_delete (wasm_extern_vec_t*);

wasm_externkind_t wasm_extern_kind (const(wasm_extern_t)*);
wasm_externtype_t* wasm_extern_type (const(wasm_extern_t)*);

wasm_extern_t* wasm_func_as_extern (wasm_func_t*);
wasm_extern_t* wasm_global_as_extern (wasm_global_t*);
wasm_extern_t* wasm_table_as_extern (wasm_table_t*);
wasm_extern_t* wasm_memory_as_extern (wasm_memory_t*);

wasm_func_t* wasm_extern_as_func (wasm_extern_t*);
wasm_global_t* wasm_extern_as_global (wasm_extern_t*);
wasm_table_t* wasm_extern_as_table (wasm_extern_t*);
wasm_memory_t* wasm_extern_as_memory (wasm_extern_t*);

const(wasm_extern_t)* wasm_func_as_extern_const (const(wasm_func_t)*);
const(wasm_extern_t)* wasm_global_as_extern_const (const(wasm_global_t)*);
const(wasm_extern_t)* wasm_table_as_extern_const (const(wasm_table_t)*);
const(wasm_extern_t)* wasm_memory_as_extern_const (const(wasm_memory_t)*);

const(wasm_func_t)* wasm_extern_as_func_const (const(wasm_extern_t)*);
const(wasm_global_t)* wasm_extern_as_global_const (const(wasm_extern_t)*);
const(wasm_table_t)* wasm_extern_as_table_const (const(wasm_extern_t)*);
const(wasm_memory_t)* wasm_extern_as_memory_const (const(wasm_extern_t)*);

// Module Instances

void wasm_instance_delete (wasm_instance_t*);
wasm_instance_t* wasm_instance_copy (const(wasm_instance_t)*);
bool wasm_instance_same (const(wasm_instance_t)*, const(wasm_instance_t)*);
void* wasm_instance_get_host_info (const(wasm_instance_t)*);
void wasm_instance_set_host_info (wasm_instance_t*, void*);
void wasm_instance_set_host_info_with_finalizer (wasm_instance_t*, void*, void function (void*));
wasm_ref_t* wasm_instance_as_ref (wasm_instance_t*);
wasm_instance_t* wasm_ref_as_instance (wasm_ref_t*);
const(wasm_ref_t)* wasm_instance_as_ref_const (const(wasm_instance_t)*);
const(wasm_instance_t)* wasm_ref_as_instance_const (const(wasm_ref_t)*);

wasm_instance_t* wasm_instance_new (
    wasm_store_t*,
    const(wasm_module_t)*,
    const(wasm_extern_vec_t)* imports,
    wasm_trap_t**);

void wasm_instance_exports (const(wasm_instance_t)*, wasm_extern_vec_t* out_);

///////////////////////////////////////////////////////////////////////////////
// Convenience

// Vectors

// Value Type construction short-hands

wasm_valtype_t* wasm_valtype_new_i32 ();
wasm_valtype_t* wasm_valtype_new_i64 ();
wasm_valtype_t* wasm_valtype_new_f32 ();
wasm_valtype_t* wasm_valtype_new_f64 ();

wasm_valtype_t* wasm_valtype_new_anyref ();
wasm_valtype_t* wasm_valtype_new_funcref ();

// Function Types construction short-hands

wasm_functype_t* wasm_functype_new_0_0 ();

wasm_functype_t* wasm_functype_new_1_0 (wasm_valtype_t* p);

wasm_functype_t* wasm_functype_new_2_0 (wasm_valtype_t* p1, wasm_valtype_t* p2);

wasm_functype_t* wasm_functype_new_3_0 (
    wasm_valtype_t* p1,
    wasm_valtype_t* p2,
    wasm_valtype_t* p3);

wasm_functype_t* wasm_functype_new_0_1 (wasm_valtype_t* r);

wasm_functype_t* wasm_functype_new_1_1 (wasm_valtype_t* p, wasm_valtype_t* r);

wasm_functype_t* wasm_functype_new_2_1 (
    wasm_valtype_t* p1,
    wasm_valtype_t* p2,
    wasm_valtype_t* r);

wasm_functype_t* wasm_functype_new_3_1 (
    wasm_valtype_t* p1,
    wasm_valtype_t* p2,
    wasm_valtype_t* p3,
    wasm_valtype_t* r);

wasm_functype_t* wasm_functype_new_0_2 (wasm_valtype_t* r1, wasm_valtype_t* r2);

wasm_functype_t* wasm_functype_new_1_2 (
    wasm_valtype_t* p,
    wasm_valtype_t* r1,
    wasm_valtype_t* r2);

wasm_functype_t* wasm_functype_new_2_2 (
    wasm_valtype_t* p1,
    wasm_valtype_t* p2,
    wasm_valtype_t* r1,
    wasm_valtype_t* r2);

wasm_functype_t* wasm_functype_new_3_2 (
    wasm_valtype_t* p1,
    wasm_valtype_t* p2,
    wasm_valtype_t* p3,
    wasm_valtype_t* r1,
    wasm_valtype_t* r2);

// Value construction short-hands

void wasm_val_init_ptr (wasm_val_t* out_, void* p);

void* wasm_val_ptr (const(wasm_val_t)* val);

///////////////////////////////////////////////////////////////////////////////

// extern "C"

// #ifdef WASM_H
