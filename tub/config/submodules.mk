
SUBMODUELS_DEPS+=$(DSRC)/wrap-secp256k1/secp256k1/autogen.sh
SUBMODUELS_DEPS+=$(DSRC)/wrap-openssl/secp256k1/config
SUBMODUELS_DEPS+=$(DSRC)/wrap-p2pgowrapper/p2pwrapper/main.go

$(SUBMODUELS_DEPS):
	$(PRECMD)
	git submodule update --init --recursive

pull-submodules:
	$(PRECMD)
	git pull --recurse-submodules

prebuild0: $(SUBMODUELS_DEPS)

env-submodules:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, SUBMODUELS_DEPS, $(SUBMODUELS_DEPS)}
	${call log.close}

env: env-submodules

help-submodules:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make pull-submodules", "Pulls the submodules"}
	${call log.close}

help: help-submodules

.PHONY: help-submodules env-submodules
