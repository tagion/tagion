DSRC_NNG := ${call dir.resolve, nng}
DTMP_NNG := $(DTMP)/nng

LD_NNG+=-lnng
LD_NNG+=-L$(DTMP_NNG)
LIBNNG := $(DTMP_NNG)/libnng.a

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

nng: $(LIBNNG)


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
