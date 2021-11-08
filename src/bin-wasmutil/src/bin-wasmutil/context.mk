DEPS += lib-basic
DEPS += lib-wasm
DEPS += lib-hibon

${call config.bin, wasmutil}: LOOKUP := tagion/*.d