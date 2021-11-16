${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}

FILENAME_DEPS_MK := get.deps.mk
ifdef TEST
FILENAME_DEPS_MK := $(GENERATED_PREFIX).test.deps.mk
endif

define depend
${eval DEPS += ${strip $1}}
${eval DEPS_$(RESOLVING_UNIT) += ${strip $1}}
endef

# define lookup
# ${eval
# resolve-$(RESOLVING_UNIT): LOOKUP += ${strip $1}
# }
# endef

# By default, INCLFLAGS contain all directories inside current ./src
INCLFLAGS := ${addprefix -I,${shell ls -d $(DIR_SRC)/*/ 2> /dev/null || true | grep -v wrap-}}
INCLFLAGS += ${addprefix -I,${shell ls -d $(DIR_BUILD_WRAPS)/*/lib 2> /dev/null || true}}

# Remove duplicates
DEPS := ${sort $(DEPS)}

# Include all context files in the scope of currenct compilation
# and marked the resolved ones, so we can decide whether to proceed
# now, or use recursive make to resolve further
${foreach DEP,$(DEPS),\
	${call debug, Including $(DEP)...}\
	${eval RESOLVING_UNIT := $(DEP)}\
	${eval -include $(DIR_SRC)/$(DEP)/resolve.mk}\
	${eval -include $(DIR_SRC)/$(DEP)/local.mk}\
	${eval DEPS_RESOLVED += $(DEP)}\
}

DEPS := ${sort $(DEPS)}
DEPS_UNRESOLVED := ${filter-out ${sort $(DEPS_RESOLVED)}, $(DEPS)}

${call debug, Deps:}
${call debug.lines, ${addprefix -,$(DEPS)}}
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
resolve-%: $(DIR_BUILD_FLAGS)/.way
	@touch $(DIR_BUILD_FLAGS)/$(*).resolved
	${if $(RECURSIVE_CALLED),@touch $(DIR_BUILD_FLAGS)/$(*).called,@$(MAKE) ${addprefix resolve-,$(DEPS_UNRESOLVED)} $(MAKECMDGOALS)}
	${eval RECURSIVE_CALLED := 1}

else
${call debug, All deps successfully resolved!}

# Generate and include compile target dependencies, so that make knows
# when to recompile
DEPS_MK := ${addsuffix /$(FILENAME_DEPS_MK),${addprefix $(DIR_SRC)/,${filter-out wrap-%,${DEPS}}}}

${call debug, Including generated compile target dependencies:}
${call debug.lines, $(DEPS_MK)}

-include $(DEPS_MK)

# Targets to generate compile target dependencies
$(DIR_SRC)/bin-%/$(FILENAME_DEPS_MK): ${call config.bin,%}
	@

$(DIR_SRC)/lib-%/$(FILENAME_DEPS_MK): ${call config.lib,%}
	@

resolve-bin-%: $(DIR_BUILD_FLAGS)/.way 
	${call generate.target.dependencies,$(LOOKUP),bin-$(*),tagion$(*),libtagion,${call bin,$(*)}}

ifdef TEST
resolve-lib-%:
	${call generate.target.dependencies,$(LOOKUP),lib-$(*),test-libtagion$(*),test-libtagion,${call lib,$(*)}}
else
resolve-lib-%:
	${call generate.target.dependencies,$(LOOKUP),lib-$(*),libtagion$(*),libtagion,${call lib,$(*)}}
endif
endif

# Using ldc2 --makedeps to generate .mk file that adds list
# of dependencies to compile targets
define generate.target.dependencies
$(PRECMD)ldc2 $(INCLFLAGS) --makedeps ${call lookup,$1,$2} -o- -of=${call filepath.o,${strip $3}} > $(DIR_SRC)/${strip $2}/$(FILENAME_DEPS_MK)
endef

define lookup
${addprefix $(DIR_SRC)/${strip $2}/,$1}
endef

define filepath.o
$(DIR_BUILD_O)/${strip $1}.o
endef

${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}
