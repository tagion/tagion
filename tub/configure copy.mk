${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}


# Parse command line arguments of make and initiate
# on-demand generation of targets:

configure: rex
	$(PRECMD)touch $(DIR_ROOT)/local.context.mk



RESOLVE_UNIT_TARGETS := ${filter configure-%, $(MAKECMDGOALS)}

ifdef RESOLVE_UNIT_TARGETS
ALL_DEPS := $(subst configure-,,$(RESOLVE_UNIT_TARGETS))
ALL_DEPS := $(sort $(ALL_DEPS))

${eval ${call debug.open, RESOLVE GOALS (LEVEL: $(MAKELEVEL))}}
${eval ${call debug, Defined MAKECMDGOALS: $(RESOLVE_UNIT_TARGETS)}}
${eval ${call debug.close, RESOLVE GOALS}}
${call debug.space}
endif

FILENAME_DEPS_MK := gen.deps.mk
FILENAME_TEST_DEPS_MK := gen.test.deps.mk

FILENAME_CURRENT_DEPS_MK := $(FILENAME_DEPS_MK)
ifdef TEST
FILENAME_CURRENT_DEPS_MK := $(FILENAME_TEST_DEPS_MK)
endif

# By default, INCLFLAGS contain all directories inside current ./src
INCLFLAGS := ${addprefix -I,${shell ls -d $(DIR_SRC)/*/ 2> /dev/null || true | grep -v wrap-}}
INCLFLAGS += ${addprefix -I,${shell ls -d $(DIR_BUILD_WRAPS)/*/lib 2> /dev/null || true}}

# Remove duplicates
ALL_DEPS := ${sort $(ALL_DEPS)}

# Include all context files in the scope of currenct compilation
# and marked the resolved ones, so we can decide whether to proceed
# now, or use recursive make to resolve further
${foreach DEP,$(ALL_DEPS),\
	${call debug, Including $(DEP)...}\
	${eval RESOLVING_UNIT := $(DEP)}\
	${eval -include $(DIR_SRC)/$(DEP)/context.mk}\
	${eval -include $(DIR_SRC)/$(DEP)/local.mk}\
	${eval $(RESOLVING_UNIT)_DEPS := $(DEPS)}\
	${eval DEPSCACHE += $(DEPS)}\
	${eval DEPS := }\
	${eval ${call debug, Deps of $(DEP):}}\
	${eval ${call debug.lines, ${addprefix -,$($(RESOLVING_UNIT)_DEPS)}}}\
	${eval DEPS_RESOLVED += $(DEP)}\
}

ALL_DEPS += $(DEPSCACHE)
ALL_DEPS := ${sort $(ALL_DEPS)}

DEPS_UNRESOLVED := ${filter-out ${sort $(DEPS_RESOLVED)}, $(ALL_DEPS)}

${call debug, All known deps:}
${call debug.lines, ${addprefix -,$(ALL_DEPS)}}
${call debug, Deps resolved:}
${call debug.lines, ${addprefix -,$(DEPS_RESOLVED)}}
${call debug, Deps unresolved:}
${call debug.lines, ${addprefix -,$(DEPS_UNRESOLVED)}}

# If there are undersolved DEPS - use recursive make to resolve 
# what's left, until no unresolved DEPS left
ifdef DEPS_UNRESOLVED
${call debug, Not all deps resolved - calling recursive make...}

# TODO: Fix for situations with multiple targets
RECURSIVE_CALLED := 
configure-%: $(DIR_BUILD_FLAGS)/.way
	@touch $(DIR_BUILD_FLAGS)/$(*).resolved
	${if $(RECURSIVE_CALLED),@touch $(DIR_BUILD_FLAGS)/$(*).called,@$(MAKE) ${addprefix configure-,$(DEPS_UNRESOLVED)} $(MAKECMDGOALS)}
	${eval RECURSIVE_CALLED := 1}

else
${call debug, All deps successfully resolved!}

# Bin
configure-lib-%: ${call config.bin,%}
	${eval $*_DEPFILES := ${shell cat $(DIR_SRC)/lib-$*/$(FILENAME_CURRENT_DEPS_MK) | grep $(DIR_SRC)}}
	${eval $*_DEPFILES := ${subst $(DIR_SRC)/,,$($*_DEPFILES)}}
	${eval $*_DEPFILES := ${foreach _,$($*_DEPFILES),${firstword ${subst /, ,$_}}}}
	${eval $*_DEPFILES := ${sort $($*_DEPFILES)}}
	${eval $*_DEPFILES := ${filter-out ${firstword $($*_DEPFILES)}, $($*_DEPFILES)}}
	$(PRECMD)echo $(DIR_BUILD_BINS)/tagion$*: ${foreach DEP,$($*_DEPFILES),${subst lib-,$(DIR_BUILD_O)/libtagion,$(DEP)}.o} >> $(DIR_SRC)/lib-$(*)/$(FILENAME_CURRENT_DEPS_MK)

${call config.bin,%}: $(DIR_BUILD_FLAGS)/.way 
	${call generate.target.dependencies,$(LOOKUP),bin-$(*),tagion$(*),libtagion,${call bin,$(*)}}

# Lib
ifdef TEST
configure-lib-%: ${call config.lib,%}
	${eval $*_DEPFILES := ${shell cat $(DIR_SRC)/lib-$*/$(FILENAME_CURRENT_DEPS_MK) | grep $(DIR_SRC)}}
	${eval $*_DEPFILES := ${subst $(DIR_SRC)/,,$($*_DEPFILES)}}
	${eval $*_DEPFILES := ${foreach _,$($*_DEPFILES),${firstword ${subst /, ,$_}}}}
	${eval $*_DEPFILES := ${sort $($*_DEPFILES)}}
	${eval $*_DEPFILES := ${filter-out ${firstword $($*_DEPFILES)}, $($*_DEPFILES)}}
	$(PRECMD)echo $(DIR_BUILD_BINS)/test-libtagion$*: ${foreach DEP,$($*_DEPFILES),${subst lib-,$(DIR_BUILD_O)/test-libtagion,$(DEP)}.o} >> $(DIR_SRC)/lib-$(*)/$(FILENAME_CURRENT_DEPS_MK)

${call config.lib,%}:
	${call generate.target.dependencies,$(LOOKUP),lib-$(*),test-libtagion$(*),test-libtagion,${call lib,$(*)}}
else
configure-lib-%: ${call config.lib,%}
	${eval $*_DEPFILES := ${shell cat $(DIR_SRC)/lib-$*/$(FILENAME_CURRENT_DEPS_MK) | grep $(DIR_SRC)}}
	${eval $*_DEPFILES := ${subst $(DIR_SRC)/,,$($*_DEPFILES)}}
	${eval $*_DEPFILES := ${foreach _,$($*_DEPFILES),${firstword ${subst /, ,$_}}}}
	${eval $*_DEPFILES := ${sort $($*_DEPFILES)}}
	${eval $*_DEPFILES := ${filter-out ${firstword $($*_DEPFILES)}, $($*_DEPFILES)}}
	$(PRECMD)echo $(DIR_BUILD_LIBS_STATIC)/libtagion$*.a: ${foreach DEP,$($*_DEPFILES),${subst lib-,$(DIR_BUILD_O)/libtagion,$(DEP)}.o} >> $(DIR_SRC)/lib-$(*)/$(FILENAME_CURRENT_DEPS_MK)

${call config.lib,%}:
	${call generate.target.dependencies,$(LOOKUP),lib-$(*),libtagion$(*),libtagion,${call lib,$(*)}}
endif
endif

# Using ldc2 --makedeps to generate .mk file that adds list
# of dependencies to compile targets
define generate.target.dependencies
$(PRECMD)ldc2 $(INCLFLAGS) --makedeps ${call lookup,$1,$2} -o- -of=${call filepath.o,${strip $3}} > $(DIR_SRC)/${strip $2}/$(FILENAME_CURRENT_DEPS_MK)
endef

define lookup
${addprefix $(DIR_SRC)/${strip $2}/,$1}
endef

define filepath.o
$(DIR_BUILD_O)/${strip $1}.o
endef

${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}
