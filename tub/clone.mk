# Cloning and resolving dependencies
clone-%: $(DIR_SRC)/%/context.mk
	${eval include $(DIR_SRC)/$*/context.mk}
	${eval DEPSR := ${shell ls $(DIR_SRC)}}
	${eval DEPSN := ${sort ${filter-out $(DEPSR),$(DEPS)}}}
	${if $(DEPSN),$(PRECMD)$(MAKE) ${addprefix clone-,$(DEPSN)},${call log.line, Done!}}

$(DIR_SRC)/%/context.mk:
	${call log.header, Cloning $* ($(BRANCH))}
	$(PRECMD)git clone ${if $(BRANCH),-b $(BRANCH)} $(GIT_ORIGIN)/core-$* $(DIR_SRC)/$*
	${call log.close}