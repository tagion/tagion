#
# Webassembly wasm
#

#WASI_WASM32=wasm32-unknown-wasi 
WASI_WASM32=wasm32-unknown-wasi
PLATFORMS+=$(WASI_WASM32)
WASI_WASM64=wasm64-unknown-wasi
PLATFORMS+=$(WASI_WASM64)

ifeq ($(PLATFORM),$(WASI_WASM32))

#include $(REPOROOT)/tools/wasi-druntime/wasi_sdk_setup.mk
#WASI_BIN=$(abspath $(REPOROOT)/tools/wasi-druntime/$(WASI_SDK))

#WASMLD:=$(WASI_BIN)/wasm-ld
TRIPLET:=wasm32-unknown-wasi
WASI_SYSROOT:=share/wasi-sysroot/lib/wasm32-wasi
endif

ifeq ($(PLATFORM),$(WASI_WASM64))

#include $(REPOROOT)/tools/wasi-druntime/wasi_sdk_setup.mk
#WASI_BIN=$(abspath $(REPOROOT)/tools/wasi-druntime/$(WASI_SDK))

#WASMLD:=$(WASI_BIN)/wasm-ld
TRIPLET:=wasm64-unknown-wasi
WASI_SYSROOT:=share/wasi-sysroot/lib/wasm64-wasi

endif

ifneq (,$(findstring wasi,$(PLATFORM)))
DC!=which ldc2
WASI_DRUNTIME_ROOT?=$(abspath $(REPOROOT)/tools/wasi-druntime)
include $(WASI_DRUNTIME_ROOT)/wasi_sdk_setup.mk
WASI_SDK_ROOT=$(abspath $(WASI_DRUNTIME_ROOT)/$(WASI_SDK))
WASI_BIN=$(abspath $(WASI_SDK_ROOT)/bin)
WASMLD?=$(WASI_BIN)/wasm-ld

LDC_RUNTIME_BUILD=$(abspath $(WASI_DRUNTIME_ROOT)/ldc-build-runtime.wasi)
LDC_RUNTIME_LIB_DIR=$(abspath $(LDC_RUNTIME_BUILD)/lib)
LDC_RUNTIME_ROOT=$(abspath $(WASI_DRUNTIME_ROOT)/ldc/runtime)
WASI_LIB+=$(LDC_RUNTIME_LIB_DIR)/libdruntime-ldc.a 
WASI_LIB+=$(LDC_RUNTIME_LIB_DIR)/libphobos2-ldc.a
WASI_SYSROOT:=$(WASI_DRUNTIME_ROOT)/$(WASI_SYSROOT)
WASI_LIB+=$(WASI_SYSROOT)/libc.a

WASI_DFLAGS+=-defaultlib=c,druntime-ldc,phobos2-ldc
WASI_DFLAGS+=-I$(LDC_RUNTIME_ROOT)/druntime/src
WASI_DFLAGS+=-I$(LDC_RUNTIME_ROOT)/phobos
#WASI_DFLAGS+=-d-version=Posix
WASI_DFLAGS+=-mtriple=wasm32-unknown-wasi
WASI_DFLAGS+=-c

WASI_DFLAGS+=-O3 -release -femit-local-var-lifetime 
WASI_DFLAGS+=-flto=thin 

WASI_LDFLAGS+=--export=__data_end
WASI_LDFLAGS+=--export=__heap_base
WASI_LDFLAGS+=--allow-undefined

endif

env-wasm:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, PLATFORM, $(PLATFORM))
	$(call log.kvp, WASI_DRUNTIME_ROOT, $(WASI_DRUNTIME_ROOT))
	$(call log.kvp, WASI_SDK_ROOT, $(WASI_SDK_ROOT))
	$(call log.kvp, WASI_BIN, $(WASI_BIN))
	$(call log.kvp, WASMLD, $(WASMLD))
	$(call log.kvp, WASI_SYSROOT, $(WASI_SYSROOT))
	$(call log.kvp, LDC_RUNTIME_BUILD, $(LDC_RUNTIME_BUILD))
	$(call log.env, WASI_LIB, $(WASI_LIB))
	$(call log.env, WASI_DFLAGS, $(WASI_DFLAGS))
	$(call log.env, WASI_LDFLAGS, $(WASI_LDFLAGS))
	$(call log.close)

.PHONY: env-wasm

env: env-wasm


