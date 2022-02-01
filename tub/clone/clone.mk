# Cloning and resolving dependencies
DEPSR := ${shell ls $(DSRC)}
DEPSN := ${sort ${filter-out $(DEPSR),$(DEPS)}}

ifdef DEPSN
clone:
	$(PRECMD)
	$(MAKE) ${foreach _,$(DEPSN),_clone-$_ }
	$(MAKE) clone
else
clone:
	$(PRECMD)
	${call log.header, Cloned units}
	${call log.lines, $(DEPSR)}
	${call log.close}
endif

_clone-%: $(DSRC)/%/context.mk
	@

clone-%: $(DSRC)/%/context.mk
	$(PRECMD)
	$(MAKE) clone

ifdef GIT_SUBMODULES
$(DSRC)/%/context.mk:
	$(PRECMD)
	${call log.header, Cloning $* ($(BRANCH))}
	cd $(DROOT); git submodule add $(GIT_ORIGIN)/core-$* src/$*
	${if $(BRANCH),cd $(DSRC)/$*; git fetch origin; git checkout $(BRANCH)} 
	${call log.close}
else
$(DSRC)/%/context.mk:
	${call log.header, Cloning $* ($(BRANCH))}
	$(PRECMD)git clone $(GIT_ORIGIN)/core-$* $(DSRC)/$*
	${if $(BRANCH),cd $(DSRC)/$*; git fetch origin; git checkout $(BRANCH)} 
	${call log.close}
endif