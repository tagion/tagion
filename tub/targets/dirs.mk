export BUILD := ${abspath ${REPOROOT}/build/}
export LOG := ${abspath ${REPOROOT}/logs/}

export DDEVNET := ${abspath ${REPOROOT}/devnet/}
export DBUILD ?= ${abspath $(BUILD)/$(PLATFORM)}
export DLOG ?= ${abspath $(LOG)/$(PLATFORM)}
export TOOLS := ${abspath $(REPOROOT)/tools}
export TRUNK ?= ${abspath $(BUILD)/trunk}

export DBIN ?= $(DBUILD)/bin
export DTMP := $(DBUILD)/tmp
export DOBJ := $(DBUILD)/obj
export DLIB := $(DBUILD)/lib
export DLOGCOV := $(DLOG)/cov
export BUILDDOC := $(BUILD)/ddoc
export DOCUSAURUS := ${abspath $(REPOROOT)/docs}
export BUILDDOCUSAURUS := $(DOCUSAURUS)/build
export TESTLOG := $(DLOG)/testlog
export FUND := $(abspath $(REPOROOT)/fundamental)
export SCRIPTS := $(DTUB)/scripts

# directories for integration and dart project
export INTEGRATION := ${abspath ${REPOROOT}/integration}

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
	$(call log.kvp, BUILDDOC, $(BUILDDOC))
	$(call log.kvp, DOCUSAURUS, $(DOCUSAURUS))
	$(call log.kvp, BUILDDOCUSAURUS, $(BUILDDOCUSAURUS))
	$(call log.kvp, DSRC, $(DSRC))
	$(call log.kvp, DTUB, $(DTUB))
	$(call log.kvp, TARGETS, $(TARGETS))
	$(call log.kvp, COLLIDER_ROOT, $(COLLIDER_ROOT))
	$(call log.kvp, BDD, $(BDD))
	$(call log.kvp, BDD_LOG, $(BDD_LOG))
	$(call log.kvp, TRUNK, $(TRUNK))
	$(call log.kvp, BDD_RESULTS, $(BDD_RESULTS))
	$(call log.kvp, DLOGCOV, $(DLOGCOV))
	$(call log.kvp, TESTLOG, $(TESTLOG))
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
