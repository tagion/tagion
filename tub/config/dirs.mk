export BUILD := ${abspath ${REPOROOT}/build/}
export LOG := ${abspath ${REPOROOT}/logs/}

export DDEVNET := ${abspath ${REPOROOT}/devnet/}
export DBUILD := ${abspath $(BUILD)/$(PLATFORM)}
export DLOG := ${abspath $(LOG)/$(PLATFORM)}
export TOOLS := ${abspath $(REPOROOT)/tools}

# New simplified flow directories
export DBIN := $(DBUILD)/bin
export DTMP := $(DBUILD)/tmp
export DOBJ := $(DBUILD)/obj
export DLIB := $(DBUILD)/lib
export DLOGCOV := $(DLOG)/cov
# export BDD_LOG := $(DLOG)/bdd
export TESTBENCH := $(DLOG)/testbench
export FUND := $(REPOROOT)/fundamental
export SCRIPTS := $(DTUB)/scripts
export TOOLS := $(REPOROOT)/tools

env-dirs:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, BUILD, $(BUILD))
	$(call log.kvp, DBUILD, $(DBUILD))
	$(call log.kvp, DBIN, $(DBIN))
	$(call log.kvp, DOBJ, $(DOBJ))
	$(call log.kvp, DTMP, $(DTMP))
	$(call log.kvp, DLIB, $(DLIB))
	$(call log.kvp, DLOG, $(DLOG))
	$(call log.kvp, DSRC, $(DSRC))
	$(call log.kvp, DTUB, $(DTUB))
	$(call log.kvp, BDD, $(BDD))
	$(call log.kvp, BDD_LOG, $(BDD_LOG))
	$(call log.kvp, BDD_RESULTS, $(BDD_RESULTS))
	$(call log.kvp, DLOGCOV, $(DLOGCOV))
	$(call log.kvp, TESTBENCH, $(TESTBENCH))
	$(call log.kvp, FUND, $(FUND))
	$(call log.kvp, SCRIPTS, $(SCRIPTS))
	$(call log.kvp, TOOLS, $(TOOLS))
	$(call log.kvp, REPOROOT, $(REPOROOT))
	$(call log.kvp, INSTALL, $(INSTALL))
	$(call log.close)

env: env-dirs

clean-logs:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(DLOG)

help-logs:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make clean-logs", "Clean all generated .log files"}
	${call log.close}

help: help-logs

clean: clean-logs
