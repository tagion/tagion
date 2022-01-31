
DFLAGS+=$(DIP25) $(DIP1000)
#
# D compiler
#
$(DOBJ)/%.o: $(PREBUILD)

$(DOBJ)/%.o: $(DSRC)/%.d
	$(PRECMD)
	${call log.kvp, compile$(MODE), $(DMODULE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $< $(DCOMPILE_ONLY) $(OUTPUT)$@

#
# Unittest
#
UNITTEST_FLAGS?=$(DUNITTEST) $(DDEBUG) $(DDEBUG_SYMBOLS)
UNITTEST_DOBJ=$(DOBJ)/unittest/
UNITTEST_BIN?=$(DBIN)/unittest

unittest: $(UNITTEST_DOBJ)/.way

ifndef DEVMODE
$(UNITTEST_BIN): $(DFILES)
	$(PRECMD)
	@echo $<
	$(DC) $(UNITTEST_FLAGS) $(DMAIN) $(DFLAGS) ${addprefix -I,$(DINC)} ${filter %.d,${sort $?}} $(LIBS) $(OUTPUT)$@

unittest-%:
	@echo
	$(MAKE) UNITTEST_BIN=$(DBIN)/$@ DSRCALL="$(DSRCS.$*)" $(DBIN)/$@
endif

ifdef UNITTEST

$(DOBJALL): MODE=-unittest

unittest: $(UNITTEST_BIN)
	$(UNITTEST_BIN)

.PHONY: unittest

$(DOBJALL):DFLAGS+=$(UNITTEST_FLAGS)
ifdef DEVMODE
$(UNITTEST_BIN): $(DOBJALL)
	$(PRECMD)
	$(DC) $(UNITTEST_FLAGS) $(DMAIN) $(DFLAGS) ${addprefix -I,$(DINC)} ${filter %.o,${sort $?}} $(LIBS) $(OUTPUT)$@

endif

else

unittest:
	mkdir -p $(DOBJ)/$@
	$(MAKE) UNITTEST=1 DOBJ=$(UNITTEST_DOBJ) $@

endif

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
	${call log.close}

help: help-unittest

env-unittest:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, UNITTEST_DOBJ, $(UNITTEST_DOBJ)}
	${call log.env, UNITTEST_FLAGS, $(UNITTEST_FLAGS)}
	${call log.env, UNITTEST_BIN, $(UNITTEST_BIN)}

env: env-unittest

# Object Clear"
clean-obj:
	$(PRECMD)
	${call log.header, $@ :: obj}
	$(RM) $(DOBJALL)
	$(RM) $(DCIRALL)

clean: clean-obj
