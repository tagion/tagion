${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}

# By default, INCLFLAGS contain all directories inside current ./src
# TODO: Use DIR_SRC instead, to support ISOLATED mode
INCLFLAGS := ${addprefix -I$(DIR_ROOT)/,${shell ls -d src/*/ | grep -v wrap-}}

# Quitely removing generated files before proceeding with dependency resolvement
ifeq ($(MAKELEVEL),0)
${shell rm -f $(DIR_SRC)/**/$(GENERATED_PREFIX).prod.source.mk || true}
${shell rm -f $(DIR_SRC)/**/$(GENERATED_PREFIX).test.source.mk || true}
endif

# Remove duplicates
DEPS := ${sort $(DEPS)}

# TODO: Clean this 'test-' in goals.mk, when adding it to DEPS
DEPS := $(subst test-,,$(DEPS))

# Include all context files in the scope of currenct compilation
# and marked the resolved ones, so we can decide whether to proceed
# now, or use recursive make to resolve further
${foreach DEP,$(DEPS),\
	${call debug, Including $(DEP) context...}\
	${eval include $(DIR_SRC)/$(DEP)/context.mk}\
	${eval DEPS_RESOLVED += $(DEP)}\
}

DEPS_UNRESOLVED := ${filter-out ${sort $(DEPS_RESOLVED)}, $(DEPS)}

${call debug, Deps: $(DEPS)}
${call debug, Deps resolved: $(DEPS_RESOLVED)}
${call debug, Deps unresolved: $(DEPS_UNRESOLVED)}

# If there are undersolved DEPS - use recursive make to resolve 
# what's left, until no unresolved DEPS left
ifdef DEPS_UNRESOLVED
${call debug, Not all deps resolved - calling recursive make...}

libtagion% tagion% test-libtagion%:
	@$(MAKE) ${addprefix resolve-,$(DEPS_UNRESOLVED)} $(MAKECMDGOALS)

# Print empty line, to skip 'nothing to be done' logs
resolve-%:
	${call log.line,}

else
${call debug, All deps successfully resolved!}

# Print empty line, to skip 'nothing to be done' logs
resolve-%: 
	${call log.line,}

# Generate and include compile target dependencies, so that make knows
# when to recompile
LIB_SOURCE_MK_BASE := ${addprefix $(DIR_SRC)/,${filter lib-%,${DEPS}}}
BIN_SOURCE_MK_BASE := ${addprefix $(DIR_SRC)/,${filter bin-%,${DEPS}}}

LIB_SOURCE_MK := ${addsuffix /$(FILENAME_SOURCE_PROD_MK),$(LIB_SOURCE_MK_BASE)}
LIB_SOURCE_MK += ${addsuffix /$(FILENAME_SOURCE_TEST_MK),$(LIB_SOURCE_MK_BASE)}
BIN_SOURCE_MK := ${addsuffix /$(FILENAME_SOURCE_PROD_MK),$(BIN_SOURCE_MK_BASE)}

${call debug, Including generated target dependencies:}
${call debug.lines, $(BIN_SOURCE_MK)}
${call debug.lines, $(LIB_SOURCE_MK)}

-include $(BIN_SOURCE_MK)
-include $(LIB_SOURCE_MK)

# Targets to generate compile target dependencies
$(DIR_SRC)/bin-%/$(FILENAME_SOURCE_PROD_MK): source-bin-%
	@

$(DIR_SRC)/lib-%/$(FILENAME_SOURCE_TEST_MK) $(DIR_SRC)/lib-%/$(FILENAME_SOURCE_PROD_MK): source-lib-%
	@

# TODO: Refactor and optimize source-* targets
source-bin-%:
	${call generate.target.dependencies,$(LOOKUP) $(LOOKUP_ONLY_PROD),bin-$(*),$(LOOKUP_WRAP) $(LOOKUP_WRAP_ONLY_PROD),prod,tagion}

source-lib-%:
	${call generate.target.dependencies,$(LOOKUP) $(LOOKUP_ONLY_PROD),lib-$(*),$(LOOKUP_WRAP) $(LOOKUP_WRAP_ONLY_PROD),prod,libtagion$(*).a,libtagion}
	${call generate.target.dependencies,$(LOOKUP) $(LOOKUP_ONLY_TEST),lib-$(*),$(LOOKUP_WRAP) $(LOOKUP_WRAP_ONLY_TEST),test,test-libtagion$(*),test-libtagion}
	
endif

# Using ldc2 --makedeps to generate .mk file that adds list
# of dependencies to compile targets
define generate.target.dependencies
$(PRECMD)ldc2 $(INCLFLAGS) --makedeps ${call lookup,$1,$2,$3} -o- -of=${call filename.o,${strip $6}$(*)} > $(call filename.source,$(*),$4)
${eval TARGET_DEPS_$* := ${shell ldc2 $(INCLFLAGS) --makedeps ${call lookup,$1,$2,$3} -o- -of=${call filename.o,${strip $6}$(*)}}}
${eval TARGET_DEPS_$* := ${subst $(DIR_SRC)/,,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${subst /,.dir ,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${filter lib-%,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${subst .dir,,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${sort $(TARGET_DEPS_$*)}}
$(PRECMD)echo "" >> ${call filename.source,$(*),$4}
$(PRECMD)echo $(DIR_BUILD_BINS)/${strip $5}: ${foreach _,$(TARGET_DEPS_$*),${subst lib-,${strip $6},$(DIR_BUILD_O)/$(_).o}} >> ${call filename.source,$(*),$4}
endef

define lookup
${addprefix $(DIR_SRC)/${strip $2}/,$1} ${addprefix $(DIR_BUILD_WRAPS)/,${strip $3}}
endef

define filename.source
$(DIR_SRC)/lib-${strip $1}/$(GENERATED_PREFIX).${strip $2}.source.mk
endef

define filename.o
$(DIR_BUILD_O)/${strip $1}.o
endef

${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}