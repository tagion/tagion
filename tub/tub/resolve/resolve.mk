${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}

# By default, INCLFLAGS contain all directories inside current ./src
INCLFLAGS := ${addprefix -I,${shell ls -d $(DIR_SRC)/*/ 2> /dev/null || true | grep -v wrap-}}
INCLFLAGS += ${addprefix -I,${shell ls -d $(DIR_BUILD_WRAPS)/*/lib 2> /dev/null || true}}

# Show warning on empty deps files
EMPTY_DEPS := ${shell find $(DIR_SRC) -name $(FILENAME_DEPS_MK) -size 0}
ifdef EMPTY_DEPS
$(call print, Expected failed compilation, Why: Found empty $(FILENAME_DEPS_MK), Fix: make clean THEN make resolve-<target>)
endif

# Remove duplicates
DEPS := ${sort $(DEPS)}

# Include all context files in the scope of currenct compilation
# and marked the resolved ones, so we can decide whether to proceed
# now, or use recursive make to resolve further
${foreach DEP,$(DEPS),\
	${call debug, Including $(DEP) context...}\
	${eval -include $(DIR_SRC)/$(DEP)/context.mk}\
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
libtagion% tagion%: $(DIR_BUILD_FLAGS)/.way
	${if $(RECURSIVE_CALLED),@touch $(DIR_BUILD_FLAGS)/$(*).called,@$(MAKE) ${addprefix resolve-,$(DEPS_UNRESOLVED)} $(MAKECMDGOALS)}
	${eval RECURSIVE_CALLED := 1}

resolve-%: $(DIR_BUILD_FLAGS)/.way
	@touch $(DIR_BUILD_FLAGS)/$(*).resolved

else
${call debug, All deps successfully resolved!}

resolve-%: $(DIR_BUILD_FLAGS)/.way 
	@touch $(DIR_BUILD_FLAGS)/$(*).resolved

# Generate and include compile target dependencies, so that make knows
# when to recompile
BIN_DEPS_MK := ${addsuffix /$(FILENAME_DEPS_MK),${addprefix $(DIR_SRC)/,${filter bin-%,${DEPS}}}}
LIB_DEPS_MK := ${addsuffix /$(FILENAME_DEPS_MK),${addprefix $(DIR_SRC)/,${filter lib-%,${DEPS}}}}

${call debug, Including generated compile target dependencies:}
${call debug.lines, $(BIN_DEPS_MK)}
${call debug.lines, $(LIB_DEPS_MK)}

-include $(BIN_DEPS_MK)
-include $(LIB_DEPS_MK)

# Targets to generate compile target dependencies
$(DIR_SRC)/bin-%/$(FILENAME_DEPS_MK): ${call config.bin,%}
	@

$(DIR_SRC)/lib-%/$(FILENAME_DEPS_MK): ${call config.lib,%}
	@

${call config.bin,%}:
	${call generate.target.dependencies,$(LOOKUP),bin-$(*),tagion$(*),libtagion,${call bin,$(*)}}

ifdef TEST
${call config.lib,%}:
	${call generate.target.dependencies,$(LOOKUP),lib-$(*),test-libtagion$(*),test-libtagion,${call lib,$(*)}}
else
${call config.lib,%}:
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