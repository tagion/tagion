# Cloning and resolving dependencies
DEPSR := ${shell ls $(DSRC)}
DEPSN := ${sort ${filter-out $(DEPSR),$(DEPS)}}

ifdef DEPSN
clone:
	$(PRECMD)$(MAKE) ${foreach _,$(DEPSN),_clone-$_ }
	$(PRECMD)$(MAKE) clone
else
clone:
	${call log.header, Cloned units}
	${call log.lines, $(DEPSR)}
	${call log.close}
endif

_clone-%: $(DSRC)/%/context.mk
	@

clone-%: $(DSRC)/%/context.mk
	$(PRECMD)$(MAKE) clone

$(DSRC)/%/context.mk:
	${call log.header, Cloning $* ($(BRANCH))}
	$(PRECMD)git clone $(GIT_ORIGIN)/core-$* $(DSRC)/$*
	${if $(BRANCH),$(PRECMD)cd $(DSRC)/$*; git fetch origin; git checkout $(BRANCH)} 
	${call log.close}
