
DSRC_NNG := ${call dir.resolve, nng}
DTMP_NNG := $(DTMP)/nng

ifdef DEBUG_ENABLE
CONFIGUREFLAGS_NNG+=CMAKE_BUILD_TYPE=Debug
DTMP_NNG:=$(DTMP_NNG)/debug/
else
CONFIGUREFLAGS_NNG+=CMAKE_BUILD_TYPE=Release
DTMP_NNG:=$(DTMP_NNG)/release/
endif

LIBNNG := $(DTMP_NNG)libnng.a

ifdef USE_SYSTEM_LIBS
# NNG Does not provide a .pc file,
# so you'll have to configure it manually if nng not in the regular LD search path
# We'll keep this here in case they make one in the future
# LD_NNG+=${shell pkg-config --libs nng}
LD_NNG+=-lnng
else
LD_NNG+=$(LIBNNG)
endif

ifdef NNG_ENABLE_TLS
LD_NNG+=-lmbedtls -lmbedx509 -lmbedcrypto
DVERSIONS+=withtls
NNG_CMAKE_FLAGS+=-DNNG_ENABLE_TLS=ON
ifdef MBEDTLS_ROOT_DIR
NNG_CMAKE_FLAGS+=-DMBEDTLS_ROOT_DIR=${MBEDTLS_ROOT_DIR}
endif
endif

# Used to check if the submodule has been updated
NNG_HEAD := $(REPOROOT)/.git/modules/src/wrap-nng/nng/HEAD 
NNG_GIT_MODULE := $(DSRC_NNG)/.git

$(NNG_GIT_MODULE):
	git submodule update --init --depth=1 $(DSRC_NNG)

$(NNG_HEAD): $(NNG_GIT_MODULE)

$(LIBNNG): $(DTMP_NNG)/.way $(NNG_HEAD)
	cd $(DTMP_NNG)
	$(CMAKE) $(DSRC_NNG) $(CMAKE_GENERATOR_FLAG) $(CMAKE_TOOLCHAIN_FILE_FLAG) $(addprefix -D,$(CONFIGUREFLAGS_NNG))
	$(BUILDENV_NNG) $(CMAKE) --build . $(BUILDFLAGS_SECP256K1)

ifdef USE_SYSTEM_LIBS
nng: # NOTHING TO BUILD
.PHONY: nng
else
nng: $(LIBNNG)
endif

NNGCAT=$(DTMP_NNG)/src/tools/nngcat/nngcat
INSTALLEDNNGCAT=$(INSTALL)/nngcat
$(NNGCAT): nng
install-nngcat: $(INSTALLEDNNGCAT)
$(INSTALLEDNNGCAT): $(DTMP_NNG)/src/tools/nngcat/nngcat
	$(PRECMD)
	$(CP) $(NNGCAT) $(INSTALLEDNNGCAT)

env-nng:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, LIBNNG, $(LIBNNG)}
	${call log.kvp, DTMP_NNG, $(DTMP_NNG)}
	${call log.kvp, DSRC_NNG, $(DSRC_NNG)}
	${call log.close}

.PHONY: help-nng

env: env-nng


help-nng:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-nng", "Will display this part"}
	${call log.help, "make nng", "Creates the nng library"}
	${call log.help, "make proper-nng", "Remove the nng build"}
	${call log.help, "make env-nng", "Display environment for the nng-build"}
	${call log.close}

.PHONY: help-nng

help: help-nng


proper-nng:
	$(PRECMD)
	${call log.header, $@ :: nng}
	$(RMDIR) $(DTMP_NNG)

proper: proper-nng


