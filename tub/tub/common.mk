# Bin
define bin
$(DBIN)/tagion${strip $1}
endef

define bin.o
$(DTMP)/tagion${strip $1}.o
endef

ifdef TEST
define lib
$(DBIN)/test-libtagion${strip $1}
endef

define lib.o
$(DTMP)/test-libtagion${strip $1}.o
endef
else
define lib
$(DBIN)/libtagion${strip $1}.a
endef

define lib.o
$(DTMP)/libtagion${strip $1}.o
endef
endif

# Config
define config.lib
config-lib-${strip $1}
endef

define config.bin
config-bin-${strip $1}
endef