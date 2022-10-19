

bddtest: bddfiles bddexec 

.PHONY: bddtest bddfiles

bddfiles: behaviour
	$(PRECMD)
	echo $(BEHAVIOUR) $(BDD_FLAGS)
	$(BEHAVIOUR) $(BDD_FLAGS)

# move
#collect all D files in BDD, compile, 
bddexec: $(BDDTESTS) 
	$(PRECMD)
	echo $(BDDTESTS)
	echo "WARRING!!! Not impemented yet"

.PHONY: bddexec

env-bdd:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, BDD_FLAGS, $(BDD_FLAGS)}
	${call log.env, BDD_DFLAGS, $(BDD_DFLAGS)}
	${call log.env, BDD_DFILES, $(BDD_DFILES)}
	${call log.close}

.PHONY: env-bdd

env: env-bdd

help-bdd:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-bdd", "Will display this part"}
	${call log.help, "make bddtest", "Builds and executes all BDD's"}
	${call log.help, "make bddexec", "Compiles and links all the BDD executables"}
	${call log.help, "make bddreport", "Produce visualization of the BDD-reports"}
	${call log.help, "make bddfiles", "Generated the bdd files"}
	${call log.help, "make behaviour", "Builds the BDD tool"}
	${call log.help, "make clean-bddtest", "Will remove the bdd log files"}
	${call log.close}

.PHONY: help-bdd

help: help-bdd

# del hibon filse
clean-bddtest:
	$(PRECMD)
#	rm bdd/tagion/testbench/*.d
#	rm bdd/tagion/testbench/*.gen.md

.PHONY: help-bdd

clean: clean-bddtest


