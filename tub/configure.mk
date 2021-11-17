${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}

UNITS_BIN := ${shell ls $(DIR_SRC) | grep bin-}
UNITS_LIB := ${shell ls $(DIR_SRC) | grep lib-}
UNITS_WRAP := ${shell ls $(DIR_SRC) | grep wrap-}

configure: ${addsuffix .a,${subst lib-,$(DBIN)/lib,$(UNITS_LIB)}}
	@

$(DBIN)/lib%.a: | configure-lib-o-% configure-lib-a-%
	${call log.kvp, Configured, lib-$*}

configure-lib-a-%:
	${call filter.lib.o}
	$(PRECMD)echo $(DBIN)/lib$*.a: ${foreach DEP,$($*_DEPF),${subst lib-,$(DTMP)/lib,$(DEP)}.o} >> $(DIR_SRC)/lib-$(*)/$(FCONFIGURE)

configure-lib-o-%:
	$(PRECMD)ldc2 $(INCLFLAGS) \
	--makedeps ${foreach _,$(SOURCE),${addprefix $(DIR_SRC)/lib-$*/,$_}} -o- \
	-of=$(DTMP)/lib$*.o > \
	$(DIR_SRC)/lib-$*/$(FCONFIGURE)
	@echo >> $(DIR_SRC)/lib-$*/$(FCONFIGURE)

define filter.lib.o
${eval $*_DEPF := ${shell cat $(DIR_SRC)/lib-$*/$(FCONFIGURE) | grep $(DIR_SRC)}}
${eval $*_DEPF := ${subst $(DIR_SRC)/,,$($*_DEPF)}}
${eval $*_DEPF := ${foreach _,$($*_DEPF),${firstword ${subst /, ,$_}}}}
${eval $*_DEPF := ${sort $($*_DEPF)}}
${eval $*_DEPF := ${filter-out ${firstword $($*_DEPF)}, $($*_DEPF)}}
endef

${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}
