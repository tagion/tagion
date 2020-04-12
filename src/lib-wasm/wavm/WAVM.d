module wavm.WAVM;
import wavm.c.wavm;
import std.format;
import std.conv : to;
import std.traits : ReturnType, Parameters, Unqual;
import std.typecons : isTuple;

import stdlib=core.stdc.stdlib;


@trusted
T* calloc(T)(size_t len) if (!is(T==size_t)) {
    import core.stdc.stdlib;
    return cast(T*)(stdlib.calloc(len, T.sizeof));
}

WAVMFunctionT!F WAVMFunction(F)(F func) {
    return WAVMFunctionT!F(func);
}

template toWASMType(T) {
    static if (is(T:uint) || is(T:int)) {
        enum toWASMType=wasm_valkind_enum.WASM_I32;
    }
    else static if (is(T:ulong) || is(T:long)) {
        enum toWASMType=wasm_valkind_enum.WASM_I64;
    }
    // else static if (is(T==const(ucent)) || is(T:cent)) {
    //     enum toWASMType=wasm_valkind_enum.WASM_V128;
    // }
    else static if(is(T:float)) {
        enum toWASMType=wasm_valkind_enum.WASM_F32;
    }
    else static if(is(T:double)) {
        enum toWASMType=wasm_valkind_enum.WASM_F64;
    }
    else static if(is(T==struct)) {
        enum toWASMType=wasm_valkind_enum.WASM_ANYREF;
    }
    else {
        static assert(0, format("Type %s not supported yet", T.stringof));
    }
}

@safe
struct WAVMFunctionT(F) {
    const wasm_func_callback_t callback;
    this(F func) {
        callback=createCallback(func);
    }
    /++

     +/

    @trusted
    wasm_func_callback_t createCallback(F)(F func) if (is(F==function) || is(F==delegate)) {
        alias Params=Parameters!F;
        alias Results=ReturnType!F;
        wasm_valtype_t** params=calloc!(wasm_valtype_t*)(Params.length);
        static foreach(i;0..Params.length) {
            {
                alias T=Unqual!(Params[i]);
                enum WASMType=toWASMType!T;
                params[i]=wasm_valtype_new(WASMType);
            }
        }
        wasm_valtype_t** results=null;
        scope(exit) {
            stdlib.free(params);
            stdlib.free(results);
        }
        static if (!is(Results==void)) {
            static if (isTuple!Results) {
                results=calloc!(wasm_valtype_t*)(Results.length);

                size_t index;
                static foreach(i;0..Results.length) {
                    {
                        alias T=Unqual!(Results.Types[i]);
                        enum WASMType=toWASMType!T;
                        // This line causes a link error in DMD64 D Compiler v2.090.1
                        // results[i]=wasm_valtype_new(WASMType);
                        // But this works
                        enum code=format("results[%d]=wasm_valtype_new(WASMType);", i);

                        mixin(code);
                    }
                }
            }
            else {
                results=calloc!(wasm_valtype_t*)(1);
                enum WASMType=toWASMType!Results;
                results[0]=wasm_valtype_new(WASMType);

                //            results=calloc!(wasm_valtype_t*)();

            }
        }
//        static if (is(
        // version(none) {
        //     extern(C)
        // {
        //     wasm_trap_t* wasm_callback(const wasm_val_t* args, wasm_val_t* results)
        //     {

        //         static if (is(Parameters!F==void)) {
        //             results=null;
        //         }
        //         else {
        //         }
        //     }
        // }
        // }
        return null;
    }
}

unittest {
    import std.typecons : tuple;
    { // Simple return function
        int x2(int x) {
            return x*x;
        }
        auto wasm_x2=WAVMFunction(&x2);
    }


    { // No return value
        void ref_x2(int x, ref int y) {
            y=x*x;
        }
        auto wasm_ref_x2=WAVMFunction(&ref_x2);
    }

//    version(none)
    { // Return tuple
        auto tuple_x2(int x) {
            return tuple(x, x*x);
        }
        auto wasm_tuple_x2=WAVMFunction(&tuple_x2);
    }



    { // Parameter with struct
        struct S {
            int x;
            int y;
        }
        int struct_sub(S s) {
            return s.x-s.y;
        }
        auto wasm_struct_x2=WAVMFunction(&struct_sub);
    }

}
