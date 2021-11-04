# Source code cloning
clone-%: $(DIR_SRC)/%/context.mk
	@

# TODO: Add branch name
# TODO: In isolated mode clone only --depth
$(DIR_SRC)/%/context.mk:
	${call log.header, Cloning $(*)...}
	$(PRECMD)git clone $(GIT_ORIGIN)/core-$(*) $(DIR_SRC)/$(*)
	${call log.close}

# Shortcut for Tagion Core developers
# It will not work if you don't have access to private repositories
clone-all: ${addprefix add-, $(UNIT_LIST)}
	@