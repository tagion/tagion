ifdef CROSS_ENABLED

# TODO
# CONFIGUREFLAGS_P2PGOWRAPPER += --host=$(MTRIPLE)
# CONFIGUREFLAGS_P2PGOWRAPPER += --target=$(MTRIPLE)
# CONFIGUREFLAGS_P2PGOWRAPPER += --with-sysroot=$(CROSS_SYSROOT)

ifeq ($(findstring ios,$(CROSS_OS)),ios)
include ${call dir.resolve, cross.ios.mk}
endif

ifeq ($(findstring android,$(CROSS_OS)),android)
include ${call dir.resolve, cross.android.mk}
endif

endif