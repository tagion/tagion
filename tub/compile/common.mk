# Bin
define bin
$(DIR_BUILD_BINS)/tagion${strip $1}
endef

define bin.o
$(DIR_BUILD_O)/tagion${strip $1}.o
endef

ifdef TEST
define lib
$(DIR_BUILD_BINS)/test-libtagion${strip $1}
endef

define lib.o
$(DIR_BUILD_O)/test-libtagion${strip $1}.o
endef
else
define lib
$(DIR_BUILD_LIBS_STATIC)/libtagion${strip $1}.a
endef

define lib.o
$(DIR_BUILD_O)/libtagion${strip $1}.o
endef
endif

# Config
define config.lib
config-lib-${strip $1}
endef

define config.bin
config-bin-${strip $1}
endef