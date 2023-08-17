DSRC_NNG := ${call dir.resolve, nng}
DTMP_NNG := $(DTMP)/nng

LIBNNG := $(DTMP_NNG)/libnng.a

$(LIBNNG): $(DTMP_NNG)/.way $(REPOROOT)/.git/modules/src/wrap-nng/nng/HEAD
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

proper: proper-nng


