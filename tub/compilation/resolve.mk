${eval ${call debug.open, MAKE RESOLVE - $(MAKECMDGOALS)}}

ifeq ($(MAKELEVEL),0)
${shell rm -f $(DIR_SRC)/**/$(FILENAME_SOURCE_MK)}
endif

${eval ${call debug, DEPS: $(DEPS)}}

DEPS := ${sort $(DEPS)}
${foreach DEP,$(DEPS),\
	${eval ${call debug, Including $(DEP) context...}}\
	${eval include $(DIR_SRC)/$(DEP)/context.mk}\
	${eval DEPS_RESOLVED += $(DEP)}\
}

$(DIR_SRC)/%/$(FILENAME_SOURCE_MK):

DEPS := ${sort $(DEPS)}
DEPS_UNRESOLVED := ${filter-out ${sort $(DEPS_RESOLVED)}, $(DEPS)}

${eval ${call debug, Deps: $(DEPS)}}
${eval ${call debug, Deps resolved: $(DEPS_RESOLVED)}}
${eval ${call debug, Deps unresolved: $(DEPS_UNRESOLVED)}}

ifdef DEPS_UNRESOLVED
${eval ${call debug, Not all deps resolved, calling recursive make...}}
resolve-lib-% libtagion% tagion%:
	@$(MAKE) $(addprefix resolve-,$(DEPS_UNRESOLVED)) $(MAKECMDGOALS) | grep hello
	
else
${eval ${call debug, All deps successfully resolved}}

${call debug, Going to include source makefiles for $(DEPS)}
${foreach DEP,$(DEPS),${eval include $(DIR_SRC)/$(DEP)/$(FILENAME_SOURCE_MK)}}

resolve-%:
	${call log.line, Resolved dependencies for targets: $(MAKECMDGOALS)}
endif

$(DIR_SRC)/%/$(FILENAME_SOURCE_MK):
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps $(DIR_SRC)/$(*)/$(LOOKUP) -o- -of=$(DIR_BUILD_O)/$(subst lib-,libtagion,$(*)).o >> $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_MK)

${eval ${call debug.close, MAKE RESOLVE - $(MAKECMDGOALS)}}