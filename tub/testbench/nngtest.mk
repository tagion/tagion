.ONESHELL:
#
# Targets for NNG tests
#
NNG_DEBUG?=FALSE

NNGTEST_DBIN?=$(DBUILD)/nngtest
NNGTEST_LOG?=$(DLOG)/nngtest
NNG_ROOT?=$(REPOROOT)src/lib-nngd
LIBNNG_ROOT?=$(REPOROOT)src/lib-libnng

NNGSRC+=$(wildcard $(NNG_ROOT)/nngd/*.d)
NNGSRC+=$(wildcard $(LIBNNG_ROOT)/libnng/*.d)
NNGSRC+=$(NNGTEST_ROOT)/nngtestutil.d

NNGTEST_INC?=$(NNG_ROOT) $(NNG_ROOT)/nngd $(NNG_ROOT)/tests $(LIBNNG_ROOT) $(LIBNNG_ROOT)/libnng
NNGTEST_ROOT=$(NNG_ROOT)/tests
NNGTEST_DTESTS=$(wildcard $(NNGTEST_ROOT)/test*.d)
NNGTEST_RUNTESTS=$(addprefix $(NNGTEST_DBIN)/,$(basename $(notdir $(NNGTEST_DTESTS))))
NNGTEST_LOGS=$(addprefix $(NNGTEST_LOG)/,$(notdir $(NNGTEST_DTESTS:.d=.log)))

nngtest-build: $(NNGTEST_RUNTESTS) 

nngtest: | $(NNGTEST_DBIN)/.way $(NNGTEST_LOG)/.way

nngtest: $(NNGTEST_LOGS)

$(NNGTEST_LOG)/%.log: $(NNGTEST_DBIN)/%
	$(PRECMD)
	$(call log.header, Running $<)
	$< > $@  
	echo "Produced $@"
	grep -a '#TEST' $@ |grep -q ERROR && echo "There are errors. See nngtest.log"

#|| echo "All passed!"

$(NNGTEST_DBIN)/%: $(NNGTEST_ROOT)/%.d
	$(PRECMD)	
	$(call log.header, Build $@)
	$(DC) $(DFLAGS) $(addprefix -I,$(NNGTEST_INC)) $(LINKERFLAG)$(LIBNNG) $< $(NNGSRC) $(DOUT)$@ 
	echo "Done $*"

nngtest-pretest:
	$(PRECMD)
	echo "It will take about a minute. Be patient."
	rm -f $(NNGTEST_LOG)

nngtest-posttest:
	$(PRECMD)		
	echo "."
	grep -a '#TEST' $(NNGTEST_LOG) |grep -q ERROR && echo "There are errors. See nngtest.log" || echo "All passed!"


nngtest-test: nngtest-pretest  nngtest-posttest


.PHONY: nng nngtest-debug nngtest-build  nngtest-test nngtest-pretest nngtest-posttest

#nngtest: nngtest-build nngtest-test

.PHONY: nngtest

clean-nngtest:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(NNGTEST_DBIN)
	$(RM) $(NNGTEST_LOGS)
clean: clean-nngtest

help-nngtest:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-nngtest", "Will display this part"}
	${call log.help, "make clean-nngtest", "Clean nngtest files"}
	${call log.help, "make env-nngtest", "List all nngtest parameters"}
	${call log.help, "make nngtest", "Compiles/Links and runs the nngtests"}
	${call log.help, "make nngtest-build", "Compiles/Links the nngtest"}
	${call log.close}

help: help-nngtest

env-nngtest:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, NNGTEST_DBIN, $(NNGTEST_DBIN)}
	${call log.kvp, NNG_ROOT, $(NNG_ROOT)}
	${call log.kvp, LIBNNG_ROOT, $(LIBNNG_ROOT)}
	${call log.kvp, NNGTEST_ROOT, $(NNGTEST_ROOT)}
	${call log.kvp, NNGTEST_LOG, $(NNGTEST_LOG)}
	${call log.env, NNGTEST_INC, $(NNGTEST_INC)}
	${call log.env, NNGTEST_FLAGS, $(NNGTEST_FLAGS)}
	${call log.env, NNGTEST_DTESTS, $(NNGTEST_DTESTS)}
	${call log.env, NNGTEST_RUNTESTS, $(NNGTEST_RUNTESTS)}
	${call log.env, LIBNNG, $(LIBNNG)}
	${call log.env, NNGSRC, $(NNGSRC)}
	${call log.env, NNGTEST_LOGS, $(NNGTEST_LOGS)}
	${call log.close}

env: env-nngtest

