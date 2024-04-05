module tagion.wasmer.c.wasm_types;

import tagion.wasmer.c.wasm;

extern (C):
nothrow:
@nogc:

struct wasm_val_t {
    wasm_valkind_t kind;

    union Of {
        int i32;
        long i64;
        float32_t f32;
        float64_t f64;
        wasm_ref_t* ref_;
    }

    Of of;
    this(int x) pure {
        kind = wasm_valkind_enum.WASM_I32;
        of.i32 = x;
    }

    this(long x) pure {
        kind = wasm_valkind_enum.WASM_I64;
        of.i64 = x;
    }

    this(float x) pure {
        kind = wasm_valkind_enum.WASM_F32;
        of.f32 = x;
    }

    this(double x) pure {
        kind = wasm_valkind_enum.WASM_F64;
        of.f64 = x;
    }
}

enum wasm_init_val = wasm_val_t(wasm_valkind_enum.WASM_ANYREF);

struct wasm_val_vec_t {
    size_t size;
    wasm_val_t* data;
    this(wasm_val_t[] array) pure {
        size = array.length;
        data = array.ptr;
    }
}
