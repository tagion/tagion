# Cloning and resolving dependencies
clone-%: $(DSRC)/%/context.mk
	${eval include $(DSRC)/$*/context.mk}
	${eval DEPSR := ${shell ls $(DSRC)}}
	${eval DEPSN := ${sort ${filter-out $(DEPSR),$(DEPS)}}}
	${if $(DEPSN),$(PRECMD)$(MAKE) ${addprefix clone-,$(DEPSN)},${call log.line, Done!}}

$(DSRC)/%/context.mk:
	${call log.header, Cloning $* ($(BRANCH))}
	$(PRECMD)git clone ${if $(BRANCH),-b $(BRANCH)} $(GIT_ORIGIN)/core-$* $(DSRC)/$*
	${call log.close}