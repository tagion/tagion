
TESTPROGRAM=$(DBIN)/$(TESTMAIN)
TESTENV=$(DBIN)/bddenv.sh
BDDTESTS=${addprefix run-,$(BDDS)}
BDDBINS=${addprefix $(DBIN)/,$(BDDS)}

ALL_BDD_REPORTS=${shell find $(BDD_RESULTS) -name "*.hibon" -printf "%p "}

BDD_MD_FILES=${shell find $(BDD)/tagion -name "*.md" -a -not -name "*.gen.md"}

BDD_D_FILES:=$(BDD_MD_FILES:.md=.d)

bbdinit: DFLAGS+=$(BDDDFLAGS)

bddtest: | bddtagion bddfiles bddinit bddrun

.PHONY: bddtest bddfiles bddtagion

bddtagion: tagion
	$(PRECMD)
	$(DBIN)/tagion -f

bddfiles: $(BDD)/.done

$(BDD)/.done: $(BDD_MD_FILES)
	$(PRECMD)
	$(COLLIDER) -v $(BDD_FLAGS)
	$(TOUCH) $@

.PHONY: bddfiles

bddcontent: $(BDD)/BDDS.md

$(BDD)/BDDS.md: $(BDD_DFILES)
	$(PRECMD)
	$(DTUB)/bundle_bdd_files.d $@

.PHONY: bddcontent

bddrun: collider bddinit
	$(COLLIDER) -r $(TEST_STAGE) -b $(TESTBENCH) 

.PHONY: bddrun

ifdef VALGRIND
run-%: PRETOOL_FLAGS+=--callgrind-out-file=$(DLOG)/callgrind.$*.log
run-%: INFO+=Callgrind file stored in $(DLOG)/callgrind.$*.log
endif

run-%: bddfiles bddinit 
	$(PRECMD)
	${call log.header, $* :: run bdd}
	$(PRETOOL) $(PRETOOL_FLAGS) $(DBIN)/$* $(RUNFLAGS)
	echo $(INFO)

test-%: run-%
	$(PRECMD)
	${call log.header, $* :: test bdd}
	$(DBIN)/hibonutil -p $(ALL_BDD_REPORTS)
	$(COLLIDER) -c $(BDD_RESULTS)

ddd-%:
	$(PRECMD)
	$(DEBUGGER) $(DBIN)/$* $(RUNFLAGS)

bddenv: $(TESTENV)

.PHONY: bddenv

$(TESTENV): $(DBIN) 
	$(PRECMD)
	$(SCRIPTS)/genenv.sh $@
	chmod 750 $@

.PHONY: $(TESTENV)

startreporter.sh:
	$(PRECMD)
	$(SCRIPTS)/genreporter.sh $@

bddinit: testbench $(BDD_RESULTS)/.way $(BDD_LOG)/.way bddenv
	$(PRECMD)
	$(TESTPROGRAM) -f

.PHONY: bddinit

bddreport: 
	$(PRECMD)
	$(DBIN)/hibonutil -p $(ALL_BDD_REPORTS)
	$(COLLIDER) -cv $(BDD_RESULTS)

.PHONY: bddreport

%.md.tmp: %.md
	$(PRECMD)
	iconv -t US-ASCII -t UTF-8//TRANSLIT//IGNORE $< > $@
	mv $@ $<

bddstrip: $(BDD_MD_FILES:.md=.md.tmp)

env-bdd:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, BDD_FLAGS, $(BDD_FLAGS)}
	${call log.env, BDD_DFLAGS, $(BDD_DFLAGS)}
	${call log.env, BDD_DFILES, $(BDD_DFILES)}
	${call log.env, BDD_MD_FILES, $(BDD_MD_FILES)}
	${call log.env, TESTENV, $(TESTENV)}
	${call log.kvp, TESTMAIN, $(TESTMAIN)}
	${call log.kvp, TESTPROGRAM, $(TESTPROGRAM)}
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
	${call log.help, "make test-<bddname>", "Runs the <bddname> and print out the tests"}
	${call log.help, "make bddreport", "Produce visualization of the BDD-reports"}
	${call log.help, "make bddfiles", "Generates the bdd files"}
	${call log.help, "make bddenv", "Generates a environment test script"}
	${call log.help, "make bddinit", "Initialize the testbench tool"}
	${call log.help, "make bddstrip", "Strips bad chars from BDD markdown files "}
	${call log.help, "make collider", "Builds the BDD tool"}
	${call log.help, "make clean-bddtest", "Remove the bdd log files"}
	${call log.help, "make clean-reports", "Remove all the bdd reports"}
	${call log.help, "make clean-bdd", "Remove all the bdd files"}
	${call log.help, "make list-bdd", "List all bdd targets"}
	${call log.close}

.PHONY: help-bdd

help: help-bdd

clean-reports:
	$(PRECMD)
	$(RMDIR) $(BDD_RESULTS)

# Delete all files related to bdd
clean-bdd: clean-bddtest clean-reports
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(COLLIDER) $(COLLIDER).o $(TESTPROGRAM) $(TESTPROGRAM).o $(BDDBINS)

# Delete hibon files
clean-bddtest:
	$(PRECMD)
	$(RMDIR) $(BDD_LOG)

clean: clean-bddtest clean-bdd
