module tagion.wasmer.engine;

import tagion.wasmer.c;

struct Engine {
    private { 
        wasm_config_t* _config;
        
    }
//    this(
    @disable this(this);
    ~this() {
         
    }
}
