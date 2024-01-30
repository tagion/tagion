
TRUNK_TAR_FILE:=$(BUILD)/trunk.tgz

TRUNK_DIRS+=$(DLOG)
TRUNK_DIRS+=$(DBIN)

.PHONY: $(TRUNK_TAR_FILE)
.PHONY: trunk trunk-tar

trunk: copy_trunk_files

trunk-tar: trunk
	tar czf ${TRUNK_TAR_FILE} --directory=${TRUNK}/ .

.PHONY: clean-trunk
clean-trunk:
	${PRECMD}
	${call log.header, $@ :: clean}
	$(RM) $(TRUNK_TAR_FILE)
	$(RM) -r $(TRUNK)
	${call log.close}

clean: clean-trunk

copy_trunk_files:
	mkdir -p ${TRUNK}
	find ${shell realpath --relative-to $(REPOROOT) $(TRUNK_DIRS)} -type f -not -name "*.way" -not -name "*.o" -not -name "*-cov" -exec cp --parents {} ${TRUNK} \;
	find -name "*.callstack" -exec cp {} ${TRUNK} \;

	# Extra files
	mkdir -p ${TRUNK}/scripts ${TRUNK}/.config/systemd/user
	$(CP) tub/targets/install.mk ${TRUNK}/GNUmakefile
	$(CP) $(REPOROOT)/collider_schedule.json ${TRUNK}
	$(CP) $(DSRC)/bin-tagionshell/tagionshell.service $(DSRC)/bin-wave/neuewelle.service ${TRUNK}/.config/systemd/user
	$(CP) $(DTUB)/scripts/create_wallets.sh ${TRUNK}/scripts
	$(CP) $(DTUB)/scripts/run_ops.sh $(TRUNK)/scripts
	$(CP) $(DTUB)/scripts/run_network.sh $(TRUNK)/scripts
	$(CP) $(DTUB)/scripts/failed.sh $(TRUNK)/scripts

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
