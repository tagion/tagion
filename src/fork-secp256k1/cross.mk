ifdef CROSS_ENABLED

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
