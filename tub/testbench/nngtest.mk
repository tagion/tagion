#
# Targets for NNG tests
#
NNG_DEBUG?=FALSE
NNG_WITH_MBEDTLS?=OFF

NNGTEST_DBIN?=$(DBIN)/nngtest
NNGTEST_LOG?=$(DLOG)/nngtest.log
NNG_ROOT?=$(REPOROOT)src/lib-nngd
LIBNNG_ROOT?=$(REPOROOT)src/lib-libnng

NNGTEST_INC?=$(NNG_ROOT) $(NNG_ROOT)/nngd $(NNG_ROOT)/tests $(LIBNNG_ROOT) $(LIBNNG_ROOT)/libnng
NNGTEST_DL?=$(addprefix -L,$(realpath $(dir $(LD_NNG)))) -lnng
NNGTEST_FLAGS=$(DFLAGS) -O -d -m64 -i -od=$(NNGTEST_DBIN) -of=$(NNGTEST_DBIN)/$(basename $(notdir $@)) $(addprefix -I,$(DINC)) $(addprefix -I,$(NNGTEST_INC)) $(addprefix -L,$(NNGTEST_DL))
NNGTEST_DTESTS=$(wildcard $(NNG_ROOT)/tests/test*.d)
NNGTEST_RUNTESTS=$(basename $(notdir $(NNGTEST_DTESTS)))

TMP_NNGTEST:=$(TMP_FILE)

nngtest-debug:
	$(PRECMD)
	@echo $(DC)

nngtest-build: nng $(NNGTEST_DTESTS)

$(NNGTEST_DTESTS):
	$(PRECMD)
	@echo -n "# building test: "$@
	$(DC) $(DFLAGS) -O -d -m64 -i -od=$(NNGTEST_DBIN) -of=$(NNGTEST_DBIN)/$(basename $(notdir $@)) $(addprefix -I,$(DINC)) $(addprefix -I,$(NNGTEST_INC)) $(addprefix -L,$(NNGTEST_DL)) $@
	@echo " ...done"

nngtest-pretest:
	@echo ""
	@echo "Logfile for details: $(NNGTEST_LOG)"
	@echo "Running tests."
	@echo "It will take about a minute. Be patient."
	rm -f $(NNGTEST_LOG)
	mkdir -p $(dir $(NNGTEST_LOG))
	cp -r $(NNG_ROOT)/tests/webapp $(NNGTEST_DBIN)
	cp -r $(NNG_ROOT)/tests/ssl $(NNGTEST_DBIN)

nngtest-posttest:
	@echo "."
	@grep -a '#TEST' $(NNGTEST_LOG) |grep -q ERROR && echo "There are errors. See nngtest.log" || echo "All passed!"


nngtest-test: nngtest-pretest $(NNGTEST_RUNTESTS) nngtest-posttest

.SILENT: $(NNGTEST_RUNTESTS)

$(NNGTEST_RUNTESTS):
	$(NNGTEST_DBIN)/$@ >> $(NNGTEST_LOG)
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
	${call log.help, "", "* Check NNGTEST_LOG for details"}
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

