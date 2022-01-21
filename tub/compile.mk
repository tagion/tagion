
#
# D compiler
#
$(DOBJ)/%.o: $(DSRC)/%.d
	$(PRECMD)
	${call log.kvp, "# Compile ", $<}
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

clean-unittest:
	$(RM) $(DOBJALL)


else
UNITTEST_DOBJ=$(DOBJ)/unittest/

unittest:
	mkdir -p $(DOBJ)/$@
	$(MAKE) UNITTEST=1 DOBJ=$(UNITTEST_DOBJ) $@

%-unittest:
	$(MAKE) UNITTEST=1
	$(MAKE) UNITTEST=1 DOBJ=$(UNITTEST_DOBJ) $@

clean: clean-unittest

endif
