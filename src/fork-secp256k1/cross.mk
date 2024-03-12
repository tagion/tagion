ifdef CROSS_ENABLED

 # To keep it as simple as possible what we call TARGET is what autotools call HOST
CONFIGUREFLAGS_SECP256K1 += --host=$(TRIPLET)
# CONFIGUREFLAGS_SECP256K1 += --with-sysroot=$(CROSS_SYSROOT)

ifeq ($(findstring ios,$(CROSS_OS)),ios)
include ${call dir.resolve, cross.ios.mk}
endif

ifeq ($(findstring android,$(CROSS_OS)),android)
include ${call dir.resolve, cross.android.mk}
endif

ifeq ($(findstring wasm,$(CROSS_OS)),wasm)
include ${call dir.resolve, cross.wasm.mk}
endif


endif
