DEPS += lib-utils

${call config.lib, wasm}: LOOKUP := tagion/vm/wasm/*.d

# TODO: fix compilation