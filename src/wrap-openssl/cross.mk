ifdef CROSS_ENABLED

CONFIGUREFLAGS_OPENSSL += --host=$(MTRIPLE)
CONFIGUREFLAGS_OPENSSL += --target=$(MTRIPLE)
CONFIGUREFLAGS_OPENSSL += --with-sysroot=$(CROSS_SYSROOT)

ifeq ($(findstring ios,$(CROSS_OS)),ios)
include ${call dir.resolve, cross.ios.mk}
endif

ifeq ($(findstring android,$(CROSS_OS)),android)
include ${call dir.resolve, cross.android.mk}
endif

endif