
import std.stdio;
import wavm.c.wavm;
import core.stdc.stdlib;

import std.array : join;

// A function to be called from Wasm code.
extern(C) {
    wasm_trap_t* hello_callback(const wasm_val_t* args, wasm_val_t* results)
    {
        writefln("hello_callback");
        printf("\targs=%p results=%p\n", args, results);
        stdout.flush;
        const wasm_val_t* args_ptr=args;
        wasm_val_t* results_ptr=results;
        printf("args %p\n\0", args);

	writefln("Hello world! (argument = %d)", args[0].i32);
        printf("results %p\n\0", results);
	results_ptr.i32 = args_ptr.i32 + 1;
        writefln("Before return");
	return null;
    }
}

int main(string[] args)
{
    // Initialize.
    wasm_engine_t* engine = wasm_engine_new();
    wasm_compartment_t* compartment = wasm_compartment_new(engine, "compartment");
    wasm_store_t* store = wasm_store_new(compartment, "store");

    string hello_wast = [
        "(module",
        "  (import \"\" \"hello\" (func $1 (param i32) (result i32)))",
        "  (func (export \"run\") (param i32) (result i32)",
        "    (call $1 (local.get 0))",
        "  )",
        ")"].join("\n");

    // Compile.
    auto wast_module = wasm_module_new_text(engine, hello_wast.ptr, hello_wast.length);
    if (!wast_module) {
        return 1;
    }

	// Create external print functions.
    wasm_valtype_t** p=cast(wasm_valtype_t**)malloc((wasm_valtype_t*).sizeof*1);
    wasm_valtype_t** r=cast(wasm_valtype_t**)malloc((wasm_valtype_t*).sizeof*1);
    scope(exit) {
        free(r);
        free(p);
    }
    printf("p.ptr=%p r.ptr=%p\n\0", p, r);
    //}
    //=new wasm_valtype_t*[1]; //new wasm_valtype_t[1];//wasm_valtype_new(wasm_valkind_enum.WASM_
//    printf("p.length=%d typeof(p)=%s %s", p.length, typeof(p), typeof(p.ptr));
//    printf("p.ptr=%p r.ptr=%p\n\0", p, r);
//    writefln("%s %s", wasm_valkind_enum.WASM_I32, typeof(wasm_valtype_new(wasm_valkind_enum.WASM_I32)).stringof);
    *p=wasm_valtype_new(wasm_valkind_enum.WASM_I32);
    *r=wasm_valtype_new(wasm_valkind_enum.WASM_I32);
    printf("p[0]=%p r[0]=%p\n\0", p[0], r[0]);
    wasm_functype_t* hello_type
//        = wasm_functype_new_1_1(wasm_valtype_new(wasm_valkind_enum.WASM_I32), wasm_valtype_new(wasm_valkind_enum.WASM_I32));
        = wasm_functype_new(p, 1, r, 1);
    wasm_func_t* hello_func = wasm_func_new(compartment, hello_type, &hello_callback, "hello\0".ptr);

    writefln("After hello_func");
    wasm_functype_delete(hello_type);
    writefln("After wasm_functype_delete");

	// Instantiate.
    wasm_extern_t** imports=cast(wasm_extern_t**)malloc((wasm_extern_t*).sizeof*1);
    scope(exit) {
        free(imports);
    }

    imports[0] = wasm_func_as_extern(hello_func);
    wasm_instance_t* instance = wasm_instance_new(store, wast_module, imports, null, "instance\0".ptr);
    if (!instance) {
        return 1;
    }

    writefln("After wasm_instance_new");
    wasm_func_delete(hello_func);
    writefln("wasm_func_delete");

    // Extract export.
    wasm_extern_t* run_extern = wasm_instance_export(instance, 0);
    if (run_extern is null) {
        return 1;
    }
    writefln("After Extract export");
    const wasm_func_t* run_func = wasm_extern_as_func(run_extern);
    if (run_func is null) {
        return 1;
    }

    writefln("Before wasm_module_delete");
    wasm_module_delete(wast_module);
    wasm_instance_delete(instance);

    // Call.
    wasm_val_t* func_args=cast(wasm_val_t*)malloc((wasm_val_t).sizeof*1);
    wasm_val_t* func_results=cast(wasm_val_t*)malloc((wasm_val_t).sizeof*1);
    scope(exit) {
        free(func_args);
        free(func_results);
    }
    printf("func_args=%p func_results=%p\n\0", func_args, func_results);
    func_args[0].i32 = 100;
    func_results[0].i32 = 42;
    if (wasm_func_call(store, run_func, func_args, func_results)) {
        return 1;
    }

    writefln("WASM call returned: %d", func_results[0].i32);

    // Shut down.
    wasm_store_delete(store);
    wasm_compartment_delete(compartment);
    wasm_engine_delete(engine);

    return 0;
}
