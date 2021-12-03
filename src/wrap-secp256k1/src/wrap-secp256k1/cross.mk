ifdef CROSS_ENABLED

CONFIGUREFLAGS_SECP256K1 += --host=$(MTRIPLE)
CONFIGUREFLAGS_SECP256K1 += --target=$(MTRIPLE)
CONFIGUREFLAGS_SECP256K1 += --with-sysroot=$(CROSS_SYSROOT)

ifeq ($(findstring ios,$(CROSS_OS)),ios)
include ${call dir.resolve, cross.ios.mk}
endif

ifeq ($(findstring android,$(CROSS_OS)),android)
include ${call dir.resolve, cross.android.mk}
endif

endif