# Source code cloning
clone: ${addprefix clone-,$(DEPS)}
	@

clone-%: $(DIR_SRC)/%/context.mk
	@

$(DIR_SRC)/%/context.mk:
	${call log.header, Cloning $* ($(BRANCH))}
	$(PRECMD)git clone ${if $(BRANCH),-b $(BRANCH) --single-branch} $(GIT_ORIGIN)/core-$* $(DIR_SRC)/$*
	${call log.close}
	$(PRECMD)${eval include $@}
	$(PRECMD)$(MAKE) ${addprefix clone-,$(DEPS)}