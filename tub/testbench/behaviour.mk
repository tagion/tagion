
TESTPROGRAM=$(DBIN)/$(TESTMAIN)
TESTENV=$(DBIN)/bddenv.sh
BDDTESTS=${addprefix run-,$(BDDS)}

ALL_BDD_REPORTS=${shell find $(BDD_RESULTS) -name "*.hibon" -printf "%p "}

bddtest: | bddfiles bddinit bddenv bddrun bddreport reporter-start
	$(PRECMD)

.PHONY: bddtest bddfiles

bddfiles: behaviour
	$(PRECMD)
	$(BEHAVIOUR) $(BDD_FLAGS)

bddrun: $(BDDTESTS) 

.PHONY: bddrun

run-%: bddfiles bddinit bddenv
	$(PRECMD)
	${call log.header, $* :: run bdd}
	$(DBIN)/$* $(RUNFLAGS)

bddenv: $(TESTENV)

$(TESTENV):
	$(PRECMD)
	$(SCRIPTS)/genenv.sh $@
	chmod 750 $@

.PHONY: $(TESTENV)

bddinit: $(TESTMAIN) $(BDD_RESULTS)/.way $(BDD_LOG)/.way
	$(PRECMD)
	$(TESTPROGRAM) -f

bddreport: target-hibonutil
	$(PRECMD)
	$(DBIN)/hibonutil -p $(ALL_BDD_REPORTS)


env-bdd:
	$(PRECMD)
	${call log.header, $@    :: env}
	${call log.env, BDD_FLAGS, $(BDD_FLAGS)}
	${call log.env, BDD_DFLAGS, $(BDD_DFLAGS)}
	${call log.env, BDD_DFILES, $(BDD_DFILES)}
	${call log.env, TESTENV, $(TESTENV)}
	${call log.env, BDDS, $(BDDS)}
	${call log.close}

.PHONY: env-bdd

env: env-bdd

list-bdd: 
	$(PRECMD)
	${call log.header, $@ :: list}
	${call log.env, BDDS, $(BDDS)}
	${call log.close}

help-bdd:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-bdd", "Will display this part"}
	${call log.help, "make bddtest", "Builds and executes all BDD's"}
	${call log.help, "make bddrun", "Executes the already compiled BDD's"}
	${call log.help, "make run-<bddname>", "Runs the <bddname>"}
	${call log.help, "make bddreport", "Produce visualization of the BDD-reports"}
	${call log.help, "make bddfiles", "Generates the bdd files"}
	${call log.help, "make bddenv", "Generates a environment test script"}
	${call log.help, "make bddinit", "Initialize the testbench tool"}
	${call log.help, "make behaviour", "Builds the BDD tool"}
	${call log.help, "make clean-bddtest", "Will remove the bdd log files"}
	${call log.help, "make list-bdd", "List all bdd targets"}
	${call log.close}

.PHONY: help-bdd

help: help-bdd

# del hibon filse
clean-bddtest:
	$(PRECMD)
	$(RMDIR) $(BDD_LOG)


.PHONY: help-bdd

clean: clean-bddtest


