# Source code cloning
clone-%: $(DIR_SRC)/%/context.mk
	@

$(DIR_SRC)/%/context.mk:
	${call log.header, Cloning $(*), branch $(BRANCH)}
	$(PRECMD)git clone ${if $(BRANCH),-b $(BRANCH) --single-branch} $(GIT_ORIGIN)/core-$(*) $(DIR_SRC)/$(*)
	${call log.close}

# Shortcut for Tagion Core developers
# It will not work if you don't have access to private repositories
clone-all: ${addprefix clone-, $(UNIT_LIST)}
	@