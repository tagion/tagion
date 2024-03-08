#
# Webassembly wasm
#

#WASI_WASM32=wasm32-unknown-wasi 
WASI_WASM32=wasm32-unknown-wasi
PLATFORMS+=$(WASI_WASM32)
WASI_WASM64=wasm64-unknown-wasi
PLATFORMS+=$(WASI_WASM64)

ifeq ($(PLATFORM),$(WASI_WASM32))

TRIPLET:=wasm32-unknown-wasi
#WASI_SYSROOT:=share/wasi-sysroot/lib/wasm32-wasi
WASI_SYSROOT:=share/wasi-sysroot/lib/wasm32-wasi-threads
endif

ifeq ($(PLATFORM),$(WASI_WASM64))

TRIPLET:=wasm64-unknown-wasi
WASI_SYSROOT:=share/wasi-sysroot/lib/wasm64-wasi
#WASI_SYSROOT:=share/wasi-sysroot/lib/wasm64-wasi-threads

endif

ifneq (,$(findstring wasi,$(PLATFORM)))
# Exclude stand bin linker
DBIN_EXCLUDE=1

#SPLIT_LINKER=1
#DEFAULT_BIN_DISABLE=1
ifneq ($(COMPILER),ldc)
$(error $(PLATFORM) only supports ldc2 for now)
endif


WASI_DRUNTIME_ROOT?=$(abspath $(REPOROOT)/tools/wasi-druntime)
-include $(WASI_DRUNTIME_ROOT)/wasi_sdk_setup.mk
CROSS_OS:=$(TRIPLET)
WASI_SDK_ROOT=$(abspath $(WASI_DRUNTIME_ROOT)/$(WASI_SDK))
WASI_BIN=$(abspath $(WASI_SDK_ROOT)/bin)
WASMLD?=$(WASI_BIN)/wasm-ld
LD:=$(WASMLD)

LDC_RUNTIME_BUILD=$(DLIB)
#$(abspath $(WASI_DRUNTIME_ROOT)/ldc-build-runtime.wasi)
#LDC_RUNTIME_LIB_DIR=$(DLIB)
##$(abspath $(LDC_RUNTIME_BUILD)/lib)
LDC_RUNTIME_ROOT=$(abspath $(WASI_DRUNTIME_ROOT)/ldc/runtime)
WASI_LIB+=$(LDC_RUNTIME_BUILD)/libdruntime-ldc.a 
WASI_LIB+=$(LDC_RUNTIME_BUILD)/libphobos2-ldc.a
WASI_SYSROOT:=$(WASI_SDK_ROOT)/$(WASI_SYSROOT)
WASI_LIB+=$(WASI_SYSROOT)/libc.a
WASI_LIB+=$(WASI_SYSROOT)/librt.a
WASI_LIB+=$(WASI_SYSROOT)/libutil.a
WASI_LIB+=$(WASI_SYSROOT)/libcrypt.a
WASI_LIB+=$(WASI_SYSROOT)/libdl.a

export AR:=$(WASI_BIN)/llvm-ar
export AS:=$(WASI_BIN)/llvm-as
export CC:=$(WASI_BIN)/clang
export CXX:=$(WASI_BIN)/clang++
export LD:=$(WASI_BIN)/wasm-ld
export RANLIB:=$(WASI_BIN)/ranlib
export STRIP:=$(WASI_BIN)/strip
export STRIP:=$(WASI_BIN)/objdump
#WASI_LIB+=$(WASI_SYSROOT)/libresolv.a
#WASI_LIB+=$(WASI_SYSROOT)/libpthread.a
#WASI_LIB+=$(WASI_SYSROOT)/libwasi-emulated-process-clocks.a
#WASI_LIB+=$(WASI_SYSROOT)/crt1-command.o
#WASI_DINC+=-I$(WASI_DRUNTIME_ROOT)/ldc/runtime/druntime/src 
#WASI_DINC+=-I$(WASI_DRUNTIME_ROOT)/ldc/runtime/phobos 

#DFLAGS+=-defaultlib=c,druntime-ldc,phobos2-ldc
DFLAGS+=-I$(LDC_RUNTIME_ROOT)/druntime/src
DFLAGS+=-I$(LDC_RUNTIME_ROOT)/phobos
#DFLAGS+=-d-version=Posix
DFLAGS+=-mtriple=wasm32-unknown-wasi
#DFLAGS+=-c

DFLAGS+=-O3 -release -femit-local-var-lifetime 
DFLAGS+=-flto=thin 

WASI_LDFLAGS+=--export=__data_end
WASI_LDFLAGS+=--export=__heap_base
WASI_LDFLAGS+=--allow-undefined


#DFILES+=$(TVM_SDK_DFILES)
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
	$(call log.env, WASI_DINC, $(WASI_DINC))
	$(call log.env, WASI_DFLAGS, $(WASI_DFLAGS))
	$(call log.env, WASI_LDFLAGS, $(WASI_LDFLAGS))
	$(call log.close)

.PHONY: env-wasm

env: env-wasm


