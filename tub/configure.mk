# Multi-stage configure
# Recursive make is used to ensure all side effects
# of preconfigure are included

# Preconfigure is used to ensure certain things exist
# before proceeding to normal configure
%.preconfigure:
	${call log.kvp, Preconfigured, $*}

preconfigure: | \
	${addsuffix .preconfigure,${subst wrap-,,$(UNITS_WRAP)}} \
	${addsuffix .preconfigure,${subst lib-,lib,$(UNITS_LIB)}} \
	${addsuffix .preconfigure,${subst bin-,tagion,$(UNITS_BIN)}}

preconfigure:
	@

configure:
	$(PRECMD)
	$(MAKE) preconfigure
	$(MAKE) _configure $(SUBMAKE_PARALLEL) -kij

_configure: | \
	${addsuffix .configure,${subst lib-,lib,$(UNITS_LIB)}} \
	${addsuffix .configure,${subst bin-,tagion,$(UNITS_BIN)}}

_configure:
	@

# Depending on lib%.test.configure to share scoped SOURCE variable
lib%.test.configure: makedeps.lib%.test.2
	@

makedeps.lib%.test.2: makedeps.lib%.test.1
	$(PRECMD)
	${call log.kvp, lib$(*), extending $(FCONFIGURETEST)}
	${call filter.lib.o, $(FCONFIGURETEST)}
	echo $(DBIN)/lib$*.test: ${foreach DEP,$($*_DEPF),${subst lib-,$(DTMP)/lib,$(DEP)}.test.o} >> $(DSRC)/lib-$(*)/$(FCONFIGURETEST)

makedeps.lib%.test.1:
	$(PRECMD)
	${call log.kvp, lib$(*), generating $(FCONFIGURETEST)}
	ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DSRC)/lib-$*/,$_}} -o- \
	-of=$(DTMP)/lib$*.test.o > \
	$(DSRC)/lib-$*/$(FCONFIGURETEST)
	echo >> $(DSRC)/lib-$*/$(FCONFIGURETEST)

lib%.configure: makedeps.lib%.2 lib%.test.configure
	$(PRECMD)
	${call log.kvp, lib$*, configured}

makedeps.lib%.2: makedeps.lib%.1
	$(PRECMD)
	${call log.kvp, lib$(*), extending $(FCONFIGURE)}
	${call filter.lib.o, $(FCONFIGURE)}
	echo $(DBIN)/lib$*.a: ${foreach DEP,$($*_DEPF),${subst lib-,$(DTMP)/lib,$(DEP)}.o} >> $(DSRC)/lib-$(*)/$(FCONFIGURE)

makedeps.lib%.1: 
	$(PRECMD)
	${call log.kvp, lib$(*), generating $(FCONFIGURE)}
	ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DSRC)/lib-$*/,$_}} -o- \
	-of=$(DTMP)/lib$*.o > \
	$(DSRC)/lib-$*/$(FCONFIGURE)
	echo >> $(DSRC)/lib-$*/$(FCONFIGURE)

tagion%.configure: makedeps.tagion%.2
	$(PRECMD)
	${call log.kvp, tagion$*, configured}

makedeps.tagion%.2: makedeps.tagion%.1
	$(PRECMD)
	${call log.kvp, tagion$(*), extending $(FCONFIGURE)}
	${call filter.bin.o, $(FCONFIGURE)}
	echo $(DBIN)/tagion$*: ${foreach DEP,${filter bin-%,$($*_DEPF)},${subst bin-,$(DTMP)/tagion,$(DEP)}.o} ${foreach DEP,${filter lib-%,$($*_DEPF)},${subst lib-,$(DTMP)/lib,$(DEP)}.o} >> $(DSRC)/bin-$(*)/$(FCONFIGURE)

makedeps.tagion%.1: 
	$(PRECMD)
	${call log.kvp, tagion$(*), generating $(FCONFIGURE)}
	ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DSRC)/bin-$*/,$_}} -o- \
	-of=$(DTMP)/tagion$*.o > \
	$(DSRC)/bin-$*/$(FCONFIGURE)
	echo >> $(DSRC)/bin-$*/$(FCONFIGURE)

define filter.bin.o
${eval $*_DEPF := ${shell cat $(DSRC)/bin-$*/${strip $1} | grep $(DSRC)}}
${eval $*_DEPF := ${subst $(DSRC)/,,$($*_DEPF)}}
${eval $*_DEPF := ${foreach _,$($*_DEPF),${firstword ${subst /, ,$_}}}}
${eval $*_DEPF := ${sort $($*_DEPF)}}
${eval $*_DEPF := ${filter-out ${firstword $($*_DEPF)}, $($*_DEPF)}}
endef

define filter.lib.o
${eval $*_DEPF := ${shell cat $(DSRC)/lib-$*/${strip $1} | grep $(DSRC)}}
${eval $*_DEPF := ${subst $(DSRC)/,,$($*_DEPF)}}
${eval $*_DEPF := ${foreach _,$($*_DEPF),${firstword ${subst /, ,$_}}}}
${eval $*_DEPF := ${sort $($*_DEPF)}}
${eval $*_DEPF := ${filter-out ${firstword $($*_DEPF)}, $($*_DEPF)}}
endef
