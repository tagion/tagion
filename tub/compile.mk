
ifdef COV
DFLAGS+=$(DCOV)
DRTFALGS+=$(COVOPT)
COVWAY=$(DLOGCOV)/.way
endif
DFLAGS+=$(DIP25) $(DIP1000)

ifneq ($(COMPILER),gdc)
DFLAGS+=$(DPREVIEW)=inclusiveincontracts
endif

DFLAGS+=-J$(DTUB)/logos/

#
# Change extend of the LIB
#
LIBEXT=${if $(SHARED),$(DLLEXT),$(STAEXT)}

#
# D compiler
#/
$(DOBJ)/%.$(OBJEXT): $(DSRC)/%.d
	$(PRECMD)
	${call log.kvp, compile, $(MODE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $< $(DCOMPILE_ONLY) $(OUTPUT)$@


#
# Compile and link or split link
#
ifdef SPLIT_LINKER
$(DOBJ)/lib%.$(OBJEXT): $(DOBJ)/.way
	$(PRECMD)
	${call log.kvp, compile$(MODE)}
	echo ${DFILES}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} $(DCOMPILE_ONLY)  $(OUTPUT)$@

$(DLIB)/lib%.$(DLLEXT): $(DOBJ)/lib%.$(OBJEXT)
	$(PRECMD)
	${call log.kvp, split-link$(MODE)}
	echo ${filter %.$(OBJEXT),$?}
	$(LD) ${LDFLAGS} ${filter %.$(OBJEXT),$?} $(LIBS) $(OBJS) -o$@
else
$(DLIB)/%.$(DLLEXT):
	$(PRECMD)
	${call log.kvp, link$(MODE), $(DMODULE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} ${LDFLAGS} $(LIBS) $(OBJS) $(DCOMPILE_ONLY)  $(OUTPUT)$@
endif

#
# proto targets for binaries
#

$(DBIN)/%:
	$(PRECMD)
	${call log.kvp, bin$(MOD), $*}
	echo $(DFILES) > /tmp/dfiles.mk
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} ${LDFLAGS} $(LIBS) $(OBJS) $(OUTPUT)$@

#
# Proto targets for unittest
#
UNITTEST_FLAGS?=$(DUNITTEST) $(DDEBUG) $(DDEBUG_SYMBOLS) $(DMAIN)
UNITTEST_DOBJ=$(DOBJ)/unittest
UNITTEST_BIN?=$(DBIN)/unittest
UNITTEST_LOG?=$(DLOG)/unittest.log

proto-unittest-run: $(DLOG)/.way
proto-unittest-run: proto-unittest-build
	$(PRECMD)
	$(SCRIPT_LOG) $(UNITTEST_BIN) $(UNITTEST_LOG)

proto-unittest-build: $(UNITTEST_BIN)

$(UNITTEST_BIN):DFLAGS+=$(DIP25) $(DIP1000)
$(UNITTEST_BIN): $(COVWAY) $$(DFILES)
	$(PRECMD)
	echo deps $?
	echo LIBS=$(LIBS)
	$(DC) $(UNITTEST_FLAGS) $(DFLAGS) $(DRTFALGS) ${addprefix -I,$(DINC)} ${sort $(DFILES)} $(LIBS) $(OUTPUT)$@

unittest: revision

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
	${call log.help, "make build-unittest-build", "Compiles/Links the unittest"}
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

# Object Clear"
clean-obj:
	$(PRECMD)
	${call log.header, $@ :: obj}
	$(RM) $(DOBJALL)
	$(RM) $(DCIRALL)

clean: clean-obj

env-build:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, DINC, $(DINC)}

env: env-build

help-cov:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make <target> COV=1", "Enable <target> with code covarage"}
	${call log.close}

help: help-cov

env-cov:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, COVOPT, $(COVOPT)}
	${call log.close}

env: env-cov

.PHONY: env-cov help-cov
