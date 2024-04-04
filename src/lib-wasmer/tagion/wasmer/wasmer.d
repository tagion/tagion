module tagion.wasmer.engine;

import tagion.wasmer.c;

version (ENABLE_WASMER)  : struct Engine {
    private {
        wasm_config_t* _config;
        wasmer_features_t* _features;
        wasm_engine_t* _engine;
    }

    this(const bool multi_value) nothrow @nogc {
        _config = wasm_config_new();
        _features = wasmer_features_new();
        wasmer_features_multi_value(_features, multi_value);
        wasm_config_set_features(_config, _features);
        _engine = wasm_engine_new_with_config(_config);
    }

    @disable this(this);
    ~this() {

    }
}
