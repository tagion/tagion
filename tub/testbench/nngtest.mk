#
# Targets for NNG tests
#
NNG_DEBUG?=FALSE

NNGTEST_DBIN?=$(DBIN)/nngtest
NNGTEST_LOG?=$(DLOG)/nngtest.log
NNG_ROOT?=$(REPOROOT)src/lib-nngd
LIBNNG_ROOT?=$(REPOROOT)src/lib-libnng

NNGTEST_INC?=$(NNG_ROOT) $(NNG_ROOT)/nngd $(NNG_ROOT)/tests $(LIBNNG_ROOT) $(LIBNNG_ROOT)/libnng
NNGTEST_DTESTS=$(wildcard $(NNG_ROOT)/tests/test*.d)
NNGTEST_RUNTESTS=$(basename $(notdir $(NNGTEST_DTESTS)))


TMP_NNGTEST:=$(TMP_FILE)

nngtest-debug:
	$(PRECMD)
	@echo $(DC)

nngtest-build: nng $(NNGTEST_DTESTS)

$(NNGTEST_DTESTS):
	$(PRECMD)
	$(DC) $(DFLAGS) -od=$(NNGTEST_DBIN) -of=$(NNGTEST_DBIN)/$(basename $@) $(addprefix -I,$(DINC)) $(addprefix -I,$(NNGTEST_INC)) -L$(dir $(LIBNNG)) -L-lnng $@

nngtest-pretest:
	@echo "It will take about a minute. Be patient."
	rm -f $(NNGTEST_LOG)

nngtest-posttest:
	@echo "."
	@grep -a '#TEST' $(NNGTEST_LOG) |grep -q ERROR && echo "There are errors. See nngtest.log" || echo "All passed!"


nngtest-test: nngtest-pretest $(NNGTEST_RUNTESTS) nngtest-posttest

.SILENT: $(NNGTEST_RUNTESTS)

$(NNGTEST_RUNTESTS):
	$(NNGTEST_BIN)/$@ >> $(NNGTEST_LOG)
	@echo -n "."

.PHONY: nng nngtest-debug nngtest-build $(NNGTEST_DTESTS) $(NNGTEST_RUNTESTS) nngtest-test nngtest-pretest nngtest-posttest

nngtest: nngtest-build nngtest-test

.PHONY: nngtest

clean-nngtest:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(NNGTEST_DBIN)

clean: clean-nngtest

help-nngtest:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-nngtest", "Will display this part"}
	${call log.help, "make clean-nngtest", "Clean nngtest files"}
	${call log.help, "make env-nngtest", "List all nngtest parameters"}
	${call log.help, "make nngtest", "Compiles/Links and runs the nngtests"}
	${call log.help, "make nngtest-build", "Compiles/Links the nngtest"}
	${call log.help, "make nngtest-test", "Run all nngtests"}
	${call log.close}

help: help-nngtest

env-nngtest:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, NNGTEST_DBIN, $(NNGTEST_DBIN)}
	${call log.env, NNGTEST_FLAGS, $(NNGTEST_FLAGS)}
	${call log.env, NNGTEST_DTESTS, $(NNGTEST_DTESTS)}
	${call log.env, NNGTEST_RUNTESTS, $(NNGTEST_RUNTESTS)}
	${call log.env, NNGTEST_LOG, $(NNGTEST_LOG)}
	${call log.close}

env: env-nngtest

