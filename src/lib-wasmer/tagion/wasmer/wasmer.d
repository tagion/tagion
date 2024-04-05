module tagion.wasmer.engine;

import tagion.wasmer.c;

@safe:
version (ENABLE_WASMER): 
struct Engine {
    private {
        wasm_config_t* _config;
        wasmer_features_t* _features;
        wasm_engine_t* _engine;
    }

    @disable this(this);
    this(const bool multi_value) nothrow @nogc @trusted {
        _config = wasm_config_new();
        _features = wasmer_features_new();
        wasmer_features_multi_value(_features, multi_value);
        wasm_config_set_features(_config, _features);
        _engine = wasm_engine_new_with_config(_config);
    }

    ~this() @nogc @trusted {
        wasm_engine_delete(_engine); 
    }
}

struct Module {
    private {
        wasm_store_t* _store;
        wasm_module_t* _module; 
    }
    @disable this(this);
    this(ref Engine engine, const(ubyte[]) wasm) nothrow @nogc @trusted {
        wasm_byte_vec_t wasm_bytes=wasm_byte_vec_t(wasm.length, cast(char*)&wasm[0]);
        this(engine, wasm_bytes);
    //        wasm_bytes.size = wasm.length;
//        wasm_bytes.data = cast(char*)&wasm[0];
        
    }
    this(ref Engine engine, const(char[]) wat_code) nothrow @nogc @trusted {
        wasm_byte_vec_t wat;
        scope(exit) {
            wasm_byte_vec_delete(&wat);
        }
        wasm_byte_vec_t wasm_bytes;
//        scope(exit) {
//            wasm_byte_vec_delete(wasm_bytes);
//        }
        wasm_byte_vec_new(&wat, wat_code.length, &wat_code[0]);
        //was2wasm(&wat, 
    }
    private this(ref Engine engine, ref wasm_byte_vec_t wasm_bytes) nothrow @nogc @trusted {
        _store = wasm_store_new(engine._engine);
        _module = wasm_module_new(_store, &wasm_bytes); 
    }
    ~this() @nogc @trusted {
        wasm_module_delete(_module);
        wasm_store_delete(_store);
    }
}

struct Wat {
    private {
        wasm_byte_vec_t wasm_bytes;   
    }
    @disable this(this);
    this(const(char[]) wat_code) nothrow @nogc @trusted {
        wasm_byte_vec_t wat;
        wasm_byte_vec_new(&wat, wat_code.length, &wat_code[0]);
        wat2wasm(&wat, &wasm_bytes);       
    }
    ~this() @nogc @trusted {
        
    }
}
unittest {
    string wat_string =
        "(module\n" ~
        "  (type $swap_t (func (param i32 i64) (result i64 i32)))\n" ~
        "  (func $swap (type $swap_t) (param $x i32) (param $y i64) (result i64 i32)\n" ~
        "    (local.get $y)\n" ~
        "    (local.get $x))\n" ~
        "  (export \"swap\" (func $swap)))";
    auto engine=Engine(true);
    //wasm_byte_vec_t wat;
    //wasm_byte_vec_new(&wat, wat_string.length, &wat_string[0]);
    //wasm_byte_vec_t wasm_bytes;
//    wat2wasm(&wat, &wasm_bytes);
//    wasm_byte_vec_delete(&wat);


}


