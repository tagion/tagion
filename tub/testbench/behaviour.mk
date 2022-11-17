
TESTPROGRAM=$(DBIN)/$(TESTMAIN)
TESTENV=$(DBIN)/bddenv.sh
#BDDTESTS=${addprefix $(DBIN)/,$(BDDS)}

bddtest: bddfiles bddinit bddenv bddrun 

.PHONY: bddtest bddfiles

bddfiles: behaviour
	$(PRECMD)
	$(BEHAVIOUR) $(BDD_FLAGS)

bddrun: $(BDDTESTS) 
	echo $<
	echo RUN

.PHONY: bddrun

run-%: bddfiles bddinit bddenv
	$(PRECMD)
	${call log.header. $@ :: run}
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

env-bdd:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, BDD_FLAGS, $(BDD_FLAGS)}
	${call log.env, BDD_DFLAGS, $(BDD_DFLAGS)}
	${call log.env, BDD_DFILES, $(BDD_DFILES)}
	${call log.env, TESTENV, $(TESTENV)}
	${call log.env, BDDS, $(BDDS)}
	${call log.close}

.PHONY: env-bdd

env: env-bdd

help-bdd:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-bdd", "Will display this part"}
	${call log.help, "make bddtest", "Builds and executes all BDD's"}
	${call log.help, "make bddrub", "Compiles and links all the BDD executables"}
	${call log.help, "make run-<bddname>", "Runs the <bddname>"}
	${call log.help, "make bddreport", "Produce visualization of the BDD-reports"}
	${call log.help, "make bddfiles", "Generates the bdd files"}
	${call log.help, "make bddenv", "Generates a environment test script"}
	${call log.help, "make bddinit", "Initialize the testbench tool"}
	${call log.help, "make behaviour", "Builds the BDD tool"}
	${call log.help, "make clean-bdd", "Will remove the bdd log files and the testbecch"}
	${call log.close}

.PHONY: help-bdd

help: help-bdd

# del hibon filse
clean-bdd:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(BDD_LOG)

.PHONY: help-bdd

clean: clean-bdd


