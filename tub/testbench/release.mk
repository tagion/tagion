release-%:
	$(PRECMD)
	export DFLAGS=$(RELEASE_DFLAGS)
	export DBIN=$(DBIN)/release
	export DLOG=$(DLOG)/release
	export LDFLAGS=-L-s
	$(MAKE) $* DEBUG_DISABLE=1 -f$(DTUB)/main.mk   

release: release-tagion


help-release:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make release", "Compiles and links"}
	${call log.help, "make release-<target>", "Call the make <target> in release mode"}
	${call log.close}

.PHONY: help-release

help: help-release

env-release:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, RELEASE_DFLAGS, $(RELEASE_DFLAGS)}
	${call log.close}

.PHONY: env-release

env: env-release
