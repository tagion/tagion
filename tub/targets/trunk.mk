
TRUNK_FILE=$(TRUNK)/trunk.tgz

TRUNK_FLAGS+=-zcvf

TRUNK_DIRS+=$(DLOG)
TRUNK_DIRS+=$(DBIN)
TRUNK_DIRS+=$(BUILDDOC)
TRUNK_DIRS+=$(DART_API_BUILD)

TRUNK_MAKE:=$(DBIN)/Makefile

TRUNK_LIST:=$(TMP_FILE:.sh=.lst)

.PHONY: $(TRUNK_FILE)
.PHONY: trunk

trunk: $(TRUNK_FILE)

$(TRUNK_FILE): $(TRUNK_LIST) $(TRUNK)/.way #$(TRUNK_MAKE)
	tar --files-from $(TRUNK_LIST) $(TRUNK_FLAGS) $(TRUNK_FILE) 

.PHONY: clean-trunk
clean-trunk:
	${PRECMD}
	${call log.header, $@ :: clean}
	$(RM) $(TRUNK_FILE)
	${call log.close}

clean: clean-trunk

$(TRUNK_LIST):  
	find ${shell realpath --relative-to $(REPOROOT) $(TRUNK_DIRS)} -type f -not -name "*.o" -not -name "*-cov" > $@
	echo $@


# $(TRUNK_MAKE): $(FUND)/ci/Makefile
# 	$(PRECMD)
# 	$(CP) $< $@


# trunk_make: $(TRUNK_MAKE)

.PHONY: help-trunk
help-trunk:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.help, "make clean-trunk", "Erase the trunk")
	$(call log.help, "make trunk", "Creates the trunk $(TRUNK_FILE)")
	$(call log.close)

help: help-trunk

.PHONY: env-trunk
env-trunk:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, TRUNK_FILE,$(TRUNK_FILE))
	$(call log.close)

env: env-trunk


