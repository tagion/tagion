
#
# D compiler
#
$(DOBJ)/%.o: $(DSRC)/%.d
	$(PRECMD)
	${call log.kvp, compile, $(DMODULE)}
	$(DC) $(DFLAGS) ${addprefix -I,$(DINC)} $< -c $(OUTPUT)$@

#$(DOBJ)/%.o: | $(DBUILD)/gen.ddeps.mk

#
# Unittest
#
ifdef UNITTEST

unittest: $(DOBJALL)
	$(PRECMD)
	$(MKDIR) $(DBIN)
	$(DC) $(UNITTEST_FLAGS) ${addprefix -I,$(DINC)} $? $(OUTPUT)$@

clean-unittest: clean-obj
	$(PRECMD)
	${call log.header, $@ :: unittest}


else
UNITTEST_DOBJ=$(DOBJ)/unittest/

unittest:
	mkdir -p $(DOBJ)/$@
	$(MAKE) UNITTEST=1 DOBJ=$(UNITTEST_DOBJ) $@

clean-unittest: # Ignore
	@

%-unittest:
	$(MAKE) UNITTEST=1
	$(MAKE) UNITTEST=1 DOBJ=$(UNITTEST_DOBJ) $@

clean: clean-unittest

endif

# Object Clear"
clean-obj:
	$(PRECMD)
	${call log.header, $@ :: obj}
	$(RM) $(DOBJALL)
	$(RM) $(DCIRALL)

#clean: clean-obj
