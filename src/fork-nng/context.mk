
DSRC_NNG := ${call dir.resolve, nng}
DTMP_NNG := $(DTMP)/nng

include ${call dir.resolve, importc.mk} 


LIBNNG := $(DTMP_NNG)/libnng.a

ifdef USE_SYSTEM_LIBS
# NNG Does not provide a .pc file,
# so you'll have to configure it manually if nng not in the regular LD search path
# We'll keep this here in case they make one in the future
# LD_NNG+=${shell pkg-config --libs nng}
LD_NNG+=-lnng
ifdef NNG_ENABLE_TLS
LD_NNG+=-lmbedtls -lmbedx509 -lmbedcrypto
endif
else
LD_NNG+=$(LIBNNG)
endif

# Used to check if the submodule has been updated
NNG_HEAD := $(REPOROOT)/.git/modules/src/wrap-nng/nng/HEAD 
NNG_GIT_MODULE := $(DSRC_NNG)/.git

$(NNG_GIT_MODULE):
	git submodule update --init --depth=1 $(DSRC_NNG)

$(NNG_HEAD): $(NNG_GIT_MODULE)

$(LIBNNG): $(DTMP_NNG)/.way $(NNG_HEAD)
	cd $(DTMP_NNG)
	cmake $(DSRC_NNG)
	$(MAKE)

ifdef USE_SYSTEM_LIBS
nng: # NOTHING TO BUILD
.PHONY: nng
else
nng: $(LIBNNG)
endif


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
