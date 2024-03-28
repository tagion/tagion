module tagion.wasmer.c.wasm_types;

import tagion.wasmer.c.wasm : wasm_valkind_enum, wasm_val_t;

nothrow:
@nogc:
/*
wasm_val_t wasm_val(T)(T x) pure {
    with(wasm_valkind_enum)
    static if (is(T == int)) {
        
        return wasm_val_t(kind : WASM_I32, of.i32 : x);
    }
    else static if (is(T == long)) {
        return wasm_val_t(WASM_I64, x);
    }
    else static if (is(T == float)) {
        return wasm_val_t(WASM_F32, x);
    }
    else static if (is(T == double)) {
        return wasm_val_t(WASM_F64, x); 
    }
    else {
        static assert(0, T.stingof~" not supported");
    }

}
*/
mixin template wasm_val_this() {
    this(int x) pure {
        kind=wasm_valkind_enum.WASM_I32;
        of.i32 = x;
    }
    this(long x) pure {
        kind=wasm_valkind_enum.WASM_I64;
        of.i64 = x;
    }
    this(float x) pure {
        kind=wasm_valkind_enum.WASM_F32;
        of.f32 = x;
    }
    this(double x) pure {
        kind=wasm_valkind_enum.WASM_F64;
        of.f64 = x;
    }
}

enum wasm_init_val=wasm_val_t(wasm_valkind_enum.WASM_ANYREF);

mixin template wasm_val_vec_this() {
    this(wasm_val_t[] array) pure {
        size = array.length;
        data = array.ptr;
    }
}

