module tagion.script.wasm;

version(ENABLE_WASMER):

import tagion.wasmer.c;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.script.execute;
import tagion.script.common;
import tagion.script.ScriptException;

wasm_trap_t* call_add_document_func(wasm_memory_t* mem, ref uint memory_stick, wasm_func_t* func, immutable(ubyte)[] buf) {
    wasm_memory_data(mem)[memory_stick .. buf.length] = cast(char[])buf[0 .. $].dup;
    wasm_val_t[2] arguments = [wasm_val_t(memory_stick), wasm_val_t(buf.length)];
    memory_stick += buf.length;
    wasm_val_vec_t arguments_as_array = wasm_val_vec_t(arguments);
    wasm_val_t[2] results = [wasm_init_val, wasm_init_val];
    wasm_val_vec_t results_as_array = wasm_val_vec_t(results);
    return wasm_func_call(func, &arguments_as_array, &results_as_array);
}

struct WasmContractExecution {
    wasm_engine_t* engine;
    wasm_config_t* config;
    wasmer_features_t* features;
    this(int) {
        config = wasm_config_new();
        assert(features);
        features = wasmer_features_new();
        assert(features);
        wasmer_features_multi_value(features, true); // enable multi-value!
        wasm_config_set_features(config, features);
        engine = wasm_engine_new_with_config(config);
        assert(engine);
    }

    ~this() {
        wasm_config_delete(config);
        wasm_engine_delete(engine);
        wasmer_features_delete(features);
    }

    @disable this(this);

    void pay(immutable(CollectedSignedContract)* exec_contract) {
        assert(exec_contract !is null);

        Document script_doc = exec_contract.sign_contract.contract.script;
        assert(script_doc.isRecord!WasmScript);
        const script = script_doc["code"].get!Document.serialize;
        wasm_byte_vec_t* vmcode;
        wasm_byte_vec_new(vmcode, script.length, cast(immutable(char)*)&script[0]);
        assert(vmcode);
        scope(exit) wasm_byte_vec_delete(vmcode);
        wasm_store_t* store = wasm_store_new(engine);
        assert(store);
        scope(exit) wasm_store_delete(store);

        wasm_module_t* module_ = wasm_module_new(store, vmcode);
        assert(module_);
        scope(exit) wasm_module_delete(module_);
        wasm_extern_vec_t* imports;
        wasm_trap_t* trap = null;
        wasm_instance_t* instance = wasm_instance_new(store, module_, imports, &trap);
        assert(imports);
        scope(exit) wasm_extern_vec_delete(imports);
        assert(instance);
        scope(exit) wasm_instance_delete(instance);

        wasm_extern_vec_t exports;
        wasm_instance_exports(instance, &exports);
        check(exports.size == 2, "Missing exports in module");
        scope(exit) wasm_extern_vec_delete(&exports);

        uint memory_stick;
        wasm_memory_t* memory = wasm_extern_as_memory(exports.data[0]); // memory
        check(memory !is null, "No memory in export");
        // TODO: check memory size
        scope(exit) wasm_memory_delete(memory);
        wasm_func_t* script_entry_func = wasm_extern_as_func(exports.data[1]); // arity 0
        check(script_entry_func !is null, "No script entry");
        scope(exit) wasm_func_delete(script_entry_func);
        wasm_func_t* script_add_input = wasm_extern_as_func(exports.data[2]); // arity 2
        check(script_add_input !is null, "No add input");
        scope(exit) wasm_func_delete(script_add_input);
        wasm_func_t* script_add_read = wasm_extern_as_func(exports.data[3]); // arity 2
        check(script_add_read !is null, "No add read");
        scope(exit) wasm_func_delete(script_add_read);

        trap = call_add_document_func(memory, memory_stick, script_add_input, [0, 1, 2, 3]);
        check(trap !is null, "Execute error");
        trap = call_add_document_func(memory, memory_stick, script_add_read, [3, 2, 1, 0]);
        check(trap !is null, "Execute error");
        /* wasm_val_t[2] arguments = [wasm_val_t(1), wasm_val_t(long(2))]; */
        /* wasm_val_t[2] results = [wasm_init_val, wasm_init_val]; */
        /* wasm_val_vec_t arguments_as_array = wasm_val_vec_t(arguments); */
        /* wasm_val_vec_t results_as_array = wasm_val_vec_t(results); */
        /* trap = wasm_func_call(script_entry_func, &arguments_as_array, &results_as_array); */

        check(trap !is null, "Execute error");
    }
}

unittest {
    string sample_script_wat = `
        (module
          (memory (export "memory") 2 3)
          (func (export "size") (result i32) (memory.size))
          (func (export "load") (param i32) (result i32) (i32.load8_s (local.get 0)))
          (func (export "store") (param i32 i32)
            (i32.store8 (local.get 0) (local.get 1))
          )

          (data (i32.const 0x1000) "\01\02\03\04")
        )
    `;

    wasm_byte_vec_t wat;
    wasm_byte_vec_new(&wat, sample_script_wat.length, &sample_script_wat[0]);
    wasm_byte_vec_t wasm_bytes;
    wat2wasm(&wat, &wasm_bytes);
    wasm_byte_vec_delete(&wat);

    WasmScript(cast(immutable(ubyte)[])wasm_bytes.data[0, wasm_bytes.size]);
}
