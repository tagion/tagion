
UNITTEST_COV:=$(DBIN)/unittest-cov
UNITTEST_COV_FLAGS+=--DRT-covopt="dstpath:$(DLOGCOV)"

unittest-cov: proto-unittest-cov-build
	$(PRECMD)
	$(UNITTEST_COV) $(UNITTEST_COV_FLAGS) 

proto-unittest-cov-build:
	$(MAKE) UNITTEST_BIN=$(UNITTEST_COV) COV=1 unittest -f $(DTUB)/main.mk


.PHONY: clean-unittest-cov
clean-unittest-cov:
	$(PRECMD)
	$(call log.header, $@ :: clean)
	$(RM) $(UNITTEST_COV)
	$(call log.close)

clean: clean-unittest-cov

.PHONY: help-unittest-cov
help-unittest-cov:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.help, "make unittest-cov", "Creats an unittest with code-covarage")
	$(call log.help, "make env-unittest-cov", "List the params for unittest-cov")
	$(call log.close)

help: help-unittest-cov

.PHONY: env-unittest-cov
env-unittest-cov:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.env, UNITTEST_COV, $(UNITTEST_COV))
	$(call log.close)

env: env-unittest-cov

