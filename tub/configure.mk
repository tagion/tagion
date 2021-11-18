# Multi-stage configure
# Recursive make is used to ensure all side effects
# of preconfigure are included

# Preconfigure is used to ensure certain things exist
# before proceeding to normal configure
%.preconfigure:
	${call log.kvp, Preconfigured, $*}

preconfigure: | \
	${addsuffix .preconfigure,${subst wrap-,,$(UNITS_WRAP)}} \
	${addsuffix .preconfigure,${subst lib-,lib,$(UNITS_LIB)}}
preconfigure:
	@

configure:
	$(PRECMD)$(MAKE) preconfigure
	$(PRECMD)$(MAKE) _configure $(MAKE_PARALLEL)

_configure: | \
	${addsuffix .configure,${subst lib-,lib,$(UNITS_LIB)}}
_configure:
	@

# Depending on lib%.test.configure to share scoped SOURCE variable
lib%.test.configure: makedeps.lib%.test.2
	@

makedeps.lib%.test.2: makedeps.lib%.test.1
	${call filter.lib.o, $(FCONFIGURETEST)}
	$(PRECMD)echo $(DBIN)/test$*: ${foreach DEP,$($*_DEPF),${subst lib-,$(DTMP)/test,$(DEP)}.o} >> $(DSRC)/lib-$(*)/$(FCONFIGURETEST)

makedeps.lib%.test.1:
	$(PRECMD)ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DSRC)/lib-$*/,$_}} -o- \
	-of=$(DTMP)/test$*.o > \
	$(DSRC)/lib-$*/$(FCONFIGURETEST)
	$(PRECMD)echo >> $(DSRC)/lib-$*/$(FCONFIGURETEST)

lib%.configure: makedeps.lib%.2 lib%.test.configure
	${call log.kvp, Configured, lib$*}

makedeps.lib%.2: makedeps.lib%.1
	${call filter.lib.o, $(FCONFIGURE)}
	$(PRECMD)echo $(DBIN)/lib$*.a: ${foreach DEP,$($*_DEPF),${subst lib-,$(DTMP)/lib,$(DEP)}.o} >> $(DSRC)/lib-$(*)/$(FCONFIGURE)

makedeps.lib%.1: 
	$(PRECMD)ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DSRC)/lib-$*/,$_}} -o- \
	-of=$(DTMP)/lib$*.o > \
	$(DSRC)/lib-$*/$(FCONFIGURE)
	$(PRECMD)echo >> $(DSRC)/lib-$*/$(FCONFIGURE)

define filter.lib.o
${eval $*_DEPF := ${shell cat $(DSRC)/lib-$*/${strip $1} | grep $(DSRC)}}
${eval $*_DEPF := ${subst $(DSRC)/,,$($*_DEPF)}}
${eval $*_DEPF := ${foreach _,$($*_DEPF),${firstword ${subst /, ,$_}}}}
${eval $*_DEPF := ${sort $($*_DEPF)}}
${eval $*_DEPF := ${filter-out ${firstword $($*_DEPF)}, $($*_DEPF)}}
endef
