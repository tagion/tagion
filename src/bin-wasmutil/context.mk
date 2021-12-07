DEPS += lib-basic
DEPS += lib-wasm
DEPS += lib-hibon

PROGRAM := tagionwasmutil

$(PROGRAM).configure: SOURCE := tagion/*.d