# Configure libs
configure: ${addsuffix .a,${subst lib-,$(DBIN)/lib,$(UNITS_LIB)}}
configure: ${subst lib-,$(DBIN)/test,$(UNITS_LIB)}

configure:
	@

$(DBIN)/test%: | makedeps-libtest-% filterdeps-libtest-%
	${call log.kvp, Configured test target, lib-$*}

$(DBIN)/lib%.a: | makedeps-lib-% filterdeps-lib-%
	${call log.kvp, Configured target, lib-$*}

filterdeps-lib-%:
	${call filter.lib.o}
	$(PRECMD)echo $(DBIN)/lib$*.a: ${foreach DEP,$($*_DEPF),${subst lib-,$(DTMP)/lib,$(DEP)}.o} >> $(DSRC)/lib-$(*)/$(FCONFIGURE)

makedeps-lib-%:
	$(PRECMD)ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DSRC)/lib-$*/,$_}} -o- \
	-of=$(DTMP)/lib$*.o > \
	$(DSRC)/lib-$*/$(FCONFIGURE)
	$(PRECMD)echo >> $(DSRC)/lib-$*/$(FCONFIGURE)

filterdeps-libtest-%:
	${call filter.lib.o}
	$(PRECMD)echo $(DBIN)/test$*: ${foreach DEP,$($*_DEPF),${subst lib-,$(DTMP)/test,$(DEP)}.o} >> $(DSRC)/lib-$(*)/$(FCONFIGURETEST)

makedeps-libtest-%:
	$(PRECMD)ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DSRC)/lib-$*/,$_}} -o- \
	-of=$(DTMP)/test$*.o > \
	$(DSRC)/lib-$*/$(FCONFIGURETEST)
	$(PRECMD)echo >> $(DSRC)/lib-$*/$(FCONFIGURETEST)

define filter.lib.o
${eval $*_DEPF := ${shell cat $(DSRC)/lib-$*/$(FCONFIGURE) | grep $(DSRC)}}
${eval $*_DEPF := ${subst $(DSRC)/,,$($*_DEPF)}}
${eval $*_DEPF := ${foreach _,$($*_DEPF),${firstword ${subst /, ,$_}}}}
${eval $*_DEPF := ${sort $($*_DEPF)}}
${eval $*_DEPF := ${filter-out ${firstword $($*_DEPF)}, $($*_DEPF)}}
endef
