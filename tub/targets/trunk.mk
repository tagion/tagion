
TRUNK_FILE=$(TRUNK)/trunk.tgz
TRUNK_BUILD+=proto-unittest-build
TRUNK_BUILD+=testbench
TRUNK_BUILD+=tagion
TRUNK_BUILD+=collider

TRUNK_FLAGS+=-zcvf

TRUNK_DIRS+=logs
TRUNK_DIRS+=$(DBIN)

TRUNK_LIST:=$(TMP_FILE:.sh=.lst)

.PHONY: trunk

trunk: $(TRUNK_FILE)
	echo test

$(TRUNK_FILE): $(TRUNK_LIST) $(TRUNK)/.way
	tar --files-from $(TRUNK_LIST) $(TRUNK_FLAGS) $(TRUNK_FILE) 

clean-trunk:
	$(RM) $(TRUNK_FILE)


test35: $(TRUNK_LIST)

$(TRUNK_LIST): $(TRUNK_BUILD)
	find ${shell realpath --relative-to $(REPOROOT) $(TRUNK_DIRS)} -type f -not -name "*.o" > $@
	echo $@

test31:
	@echo $(shell realpath --relative-to $(REPOROOT) $(TRUNK_DIRS))
	@echo $(shell realpath  $(TRUNK_DIRS))
	@echo $(TRUNK_LIST)



help-trunk:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.help, "make clean-trunk", "Erase the trunk")
	$(call log.help, "make trunk", "Creates the trunk $(TRUNK_FILE)")
	$(call log.close)

env-trunk:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, TRUNK_FILE,$(TRUNK_FILE))
	$(call log.close)
