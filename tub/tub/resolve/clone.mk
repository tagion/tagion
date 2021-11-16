# Source code cloning
clone-%: $(DIR_SRC)/%/resolve.mk
	@

$(DIR_SRC)/%/resolve.mk:
	${call log.header, Cloning $(*) ($(BRANCH))}
	$(PRECMD)git clone ${if $(BRANCH),-b $(BRANCH) --single-branch} $(GIT_ORIGIN)/core-$(*) $(DIR_SRC)/$(*)
	${call log.close}

# Shortcut for Tagion Core developers
# It will not work if you don't have access to private repositories
clone-all: ${addprefix clone-, $(UNIT_LIST)}
	@