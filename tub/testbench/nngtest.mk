#
# Targets for NNG tests
#
NNG_DEBUG?=FALSE

NNGTEST_DBIN?=$(DBUILD)/nngtest
NNGTEST_LOG?=$(DLOG)/nngtest.log
NNG_ROOT?=$(REPOROOT)src/lib-nngd
LIBNNG_ROOT?=$(REPOROOT)src/lib-libnng

NNGSRC+=$(wildcard $(NNG_ROOT)/nngd/*.d)
NNGSRC+=$(wildcard $(LIBNNG_ROOT)/libnng/*.d)
NNGSRC+=$(NNGTEST_ROOT)/nngtestutil.d

NNGTEST_INC?=$(NNG_ROOT) $(NNG_ROOT)/nngd $(NNG_ROOT)/tests $(LIBNNG_ROOT) $(LIBNNG_ROOT)/libnng
NNGTEST_ROOT=$(NNG_ROOT)/tests
NNGTEST_DTESTS=$(wildcard $(NNGTEST_ROOT)/test*.d)
NNGTEST_RUNTESTS=$(addprefix $(NNGTEST_DBIN)/,$(basename $(notdir $(NNGTEST_DTESTS))))
XNNGTEST_RUNTESTS=$(basename $(NNGTEST_DTESTS))


TMP_NNGTEST:=$(TMP_FILE)

nngtest-debug:
	$(PRECMD)
	@echo $(DC)

nngtest-build: nng $(NNGTEST_DTESTS)

#$(NNGTEST_DTESTS):
#	$(PRECMD)
#	echo NAME=$@
#	$(DC) $(DFLAGS) $(DOUTDIR)=$(NNGTEST_DBIN) $(DOUT)=$(NNGTEST_DBIN)/$(basename $@) $(addprefix -I,$(DINC)) $(addprefix -I,$(NNGTEST_INC)) $@ $(LINKERFLAG)$(LIBNNG) 

xnngtest: $(XNNGTEST_RUNTESTS)
	echo "$(XNNGTEST_RUNTESTS)"


$(NNGTEST_ROOT)/%: $(NNGTEST_ROOT)/%.d
	echo $@ $<
	echo $(NNGTEST_INC)
	$(DC) $(DFLAGS) $(addprefix -I,$(NNGTEST_INC)) $(LINKERFLAG)$(LIBNNG) $< $(NNGSRC) $(DOUT)$@ 

nngtest-pretest:
	@echo "It will take about a minute. Be patient."
	rm -f $(NNGTEST_LOG)

nngtest-posttest:
	@echo "."
	@grep -a '#TEST' $(NNGTEST_LOG) |grep -q ERROR && echo "There are errors. See nngtest.log" || echo "All passed!"


nngtest-test: nngtest-pretest $(NNGTEST_RUNTESTS) nngtest-posttest

.SILENT: $(NNGTEST_RUNTESTS)

#$(NNGTEST_RUNTESTS):
#	$(NNGTEST_BIN)/$@ >> $(NNGTEST_LOG)
#	@echo -n "."

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
	${call log.kvp, NNGTEST_DBIN, $(NNGTEST_DBIN)}
	${call log.kvp, NNG_ROOT, $(NNG_ROOT)}
	${call log.kvp, LIBNNG_ROOT, $(LIBNNG_ROOT)}
	${call log.kvp, NNGTEST_ROOT, $(NNGTEST_ROOT)}
	${call log.env, NNGTEST_INC, $(NNGTEST_INC)}
	${call log.env, NNGTEST_FLAGS, $(NNGTEST_FLAGS)}
	${call log.env, NNGTEST_DTESTS, $(NNGTEST_DTESTS)}
	${call log.env, NNGTEST_RUNTESTS, $(NNGTEST_RUNTESTS)}
	${call log.env, XNNGTEST_RUNTESTS, $(XNNGTEST_RUNTESTS)}
	${call log.env, NNGTEST_LOG, $(NNGTEST_LOG)}
	${call log.env, LIBNNG, $(LIBNNG)}
	${call log.env, NNGSRC, $(NNGSRC)}
	${call log.close}

env: env-nngtest

