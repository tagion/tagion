#
# Webassembly wasm
#

WASI_WASM32:=wasm32-unknown-wasi 
PLATFORMS+=$(WASI_WASM32)
WASI_WASM64:=wasm64-unknown-wasi 
PLATFORMS+=$(WASI_WASM64)

ifeq ($(PLATFORM),$(WASM_WASI32))

#include $(REPOROOT)/tools/wasi-druntime/wasi_sdk_setup.mk
#WASI_BIN=$(abspath $(REPOROOT)/tools/wasi-druntime/$(WASI_SDK))

#WASMLD:=$(WASI_BIN)/wasm-ld
TRIPLET:=wasm32-unknown-wasi

endif

ifeq ($(PLATFORM),$(WASM_WASI64))

#include $(REPOROOT)/tools/wasi-druntime/wasi_sdk_setup.mk
#WASI_BIN=$(abspath $(REPOROOT)/tools/wasi-druntime/$(WASI_SDK))

#WASMLD:=$(WASI_BIN)/wasm-ld
TRIPLET:=wasm64-unknown-wasi

endif

ifneq (,$(findstring wasi,$(PLATFORM)))
DC!=which ldc2

include $(REPOROOT)/tools/wasi-druntime/wasi_sdk_setup.mk
WASI_BIN=$(abspath $(REPOROOT)/tools/wasi-druntime/$(WASI_SDK))
WASMLD?=$(WASI_BIN)/wasm-ld
WASI_LIB_DIR=$(
WASI_LIB+=

endif

env-wasm:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, WAMSLD, $(WASMLD))
	$(call log.env, LIB, $(WASI_LIB))

	$(call log.close)

.PHONY: env-wasm

env: env-wasm


