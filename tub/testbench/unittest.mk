
#
# Proto targets for unittest
#
#UNITTEST_FLAGS?=$(DUNITTEST) $(DDEBUG) $(DDEBUG_SYMBOLS) $(DMAIN)
UNITTEST_DOBJ=$(DOBJ)/unittest
UNITTEST_BIN?=$(DBIN)/unittest
UNITTEST_LOG?=$(DLOG)/unittest.log

TMP_UNITTEST:=$(TMP_FILE)

ifdef VALGRIND
proto-unittest-run: PRETOOL_FLAGS+=--callgrind-out-file=$(CALLGRIND_UNITTEST_OUT)
proto-unittest-run: INFO+=Callgrind file stored in $(CALLGRIND_UNITTEST_OUT)
endif

proto-unittest-run: $(DLOG)/.way
proto-unittest-run: proto-unittest-build 
	$(PRECMD)
	$(CHEXE) $(TMP_UNITTEST)
	echo $(PRETOOL) $(PRETOOL_FLAGS) $(UNITTEST_BIN) $(DRT_FLAGS) > $(TMP_UNITTEST) 
	echo $(TMP_UNITTEST)
	$(SCRIPT_LOG) $(TMP_UNITTEST) $(UNITTEST_LOG)
	$(RM) $(TMP_UNITTEST)
	echo $(INFO)

proto-unittest-build: $(UNITTEST_BIN)

unittest-report: 
	$(PRECMD)
	cat $(UNITTEST_LOG)


.PHONY: proto-unittest-run proto-unittest-build

$(UNITTEST_BIN): DFLAGS+=$(DIP25) $(DIP1000)
$(UNITTEST_BIN): $(COVWAY) 
$(UNITTEST_BIN): $(UNITTEST_DFILES) 
	$(PRECMD)
	echo deps $?
	${call log.env, UNITTEST_DFILES,${filter %.d,$^}}
	$(DC) $(UNITTEST_FLAGS) $(DFLAGS) $(DRTFLAGS) ${addprefix -I,$(DINC)} ${sort ${filter %.d,$^}} $(LIBS) $(LDFLAGS) $(OUTPUT)$@

unittest: revision $(REPOROOT)/default.mk

.PHONY: unittest

unitmain: DFLAGS+=$(DVERSION)=unitmain
unitmain: UNITTEST_FLAGS:=$(DDEBUG) $(DDBUG_SYMBOLS)
unitmain: unittest

clean-unittest:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RMDIR) $(UNITTEST_DOBJ)
	$(RM) $(UNITTEST_BIN)

clean: clean-unittest

help-unittest:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-unittest", "Will display this part"}
	${call log.help, "make clean-unittest", "Clean unittest files"}
	${call log.help, "make env-uintest", "List all unittest parameters"}
	${call log.help, "make unittest", "Compiles/Links and runs the unittest"}
	${call log.help, "make unitmain", "Used to run a single unittest as a main" }
	${call log.help, "make proto-unittest-build", "Compiles/Links the unittest"}
	${call log.close}

help: help-unittest

env-unittest:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, UNITTEST_DOBJ, $(UNITTEST_DOBJ)}
	${call log.env, UNITTEST_FLAGS, $(UNITTEST_FLAGS)}
	${call log.env, UNITTEST_BIN, $(UNITTEST_BIN)}
	${call log.close}

env: env-unittest


