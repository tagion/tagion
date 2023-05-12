
#
# Proto targets for unitthread
#
UNITTHREAD_BIN?=$(DBIN)/unitthread
UNITTHREAD_LOG?=$(DLOG)/unitthread.log


unitthread: $(UNITTHREAD_BIN)

	


$(UNITTHREAD_BIN): DFLAGS+=$(DIP25) $(DIP1000)
$(UNITTHREAD_BIN): $(COVWAY) 
$(UNITTHREAD_BIN): $(UNITTEST_DFILES) 

$(UNITTHREAD_BIN): 
	$(PRECMD)
	$(DC) $(DTUB)/bin/ut.d $(UNITTHREAD_INC) $(UNITTEST_FLAGS) $(DFLAGS) $(DRTFLAGS) ${addprefix -I,$(DINC)} ${sort ${filter %.d,$^}} $(LIBS) $(OUTPUT)$@


test34:
	@echo DINC=$(addprefix -I,$(DINC))

