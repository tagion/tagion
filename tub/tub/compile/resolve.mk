${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}

# By default, INCLFLAGS contain all directories inside current ./src
# TODO: Use DIR_SRC instead, to support ISOLATED mode
INCLFLAGS := ${addprefix -I$(DIR_ROOT)/,${shell ls -d src/*/ | grep -v wrap-}}
INCLFLAGS += ${addprefix -I,${shell ls -d $(DIR_BUILD_WRAPS)/*/lib}}

# Quitely removing generated files before proceeding with dependency resolvement
ifeq ($(MAKELEVEL),0)
${shell rm -f $(DIR_SRC)/**/$(FILENAME_DEPS_MK) || true}
endif

# Remove duplicates
DEPS := ${sort $(DEPS)}

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

libtagion% tagion%:
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
BIN_DEPS_MK := ${addsuffix /$(FILENAME_DEPS_MK),${addprefix $(DIR_SRC)/,${filter bin-%,${DEPS}}}}
LIB_DEPS_MK := ${addsuffix /$(FILENAME_DEPS_MK),${addprefix $(DIR_SRC)/,${filter lib-%,${DEPS}}}}

${call debug, Including generated target dependencies:}
${call debug.lines, $(BIN_DEPS_MK)}
${call debug.lines, $(LIB_DEPS_MK)}

-include $(BIN_DEPS_MK)
-include $(LIB_DEPS_MK)

# Targets to generate compile target dependencies
$(DIR_SRC)/bin-%/$(FILENAME_DEPS_MK): ${call config.bin,%}
	@

$(DIR_SRC)/lib-%/$(FILENAME_DEPS_MK): ${call config.lib,%}
	@

# TODO: Refactor and optimize source-* targets
${call config.bin,%}:
	${call generate.target.dependencies,$(LOOKUP),bin-$(*),tagion$(*),libtagion,$(DIR_BUILD_BINS)}

ifdef TEST
${call config.lib,%}:
	${call generate.target.dependencies,$(LOOKUP),lib-$(*),test-libtagion$(*),test-libtagion,$(DIR_BUILD_BINS)}
else
${call config.lib,%}:
	${call generate.target.dependencies,$(LOOKUP),lib-$(*),libtagion$(*).a,libtagion,$(DIR_BUILD_LIBS_STATIC)}
endif
endif

# Using ldc2 --makedeps to generate .mk file that adds list
# of dependencies to compile targets
define generate.target.dependencies
$(PRECMD)ldc2 $(INCLFLAGS) --makedeps ${call lookup,$1,$2} -o- -of=${call filepath.o,${strip $4}$(*)} > $(DIR_SRC)/${strip $2}/$(FILENAME_DEPS_MK)
${eval TARGET_DEPS_$* := ${shell ldc2 $(INCLFLAGS) --makedeps ${call lookup,$1,$2} -o- -of=${call filepath.o,${strip $4}$(*)}}}
${eval TARGET_DEPS_$* := ${subst $(DIR_SRC)/,,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${subst /,.dir ,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${filter lib-%,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${subst .dir,,$(TARGET_DEPS_$*)}}
${eval TARGET_DEPS_$* := ${sort $(TARGET_DEPS_$*)}}
$(PRECMD)echo "" >> $(DIR_SRC)/${strip $2}/$(FILENAME_DEPS_MK)
$(PRECMD)echo ${strip $5}/${strip $3}: ${foreach _,$(LINKS),$(DIR_BUILD_WRAPS)/$(_)} ${foreach _,$(TARGET_DEPS_$*),${subst lib-,${strip $4},$(DIR_BUILD_O)/$(_).o}} >> $(DIR_SRC)/${strip $2}/$(FILENAME_DEPS_MK)
endef

define lookup
${addprefix $(DIR_SRC)/${strip $2}/,$1}
endef

define filepath.o
$(DIR_BUILD_O)/${strip $1}.o
endef

${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}