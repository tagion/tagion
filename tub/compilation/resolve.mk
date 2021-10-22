${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}

ifeq ($(MAKELEVEL),0)
${shell rm -f $(DIR_SRC)/**/$(FILENAME_SOURCE_MK) || true}
endif

DEPS := ${sort $(DEPS)}
DEPS := $(subst test-,,$(DEPS))

${call debug, DEPS: $(DEPS)}

${foreach DEP,$(DEPS),\
	${call debug, Including $(DEP) context...}\
	${eval include $(DIR_SRC)/$(DEP)/context.mk}\
	${eval DEPS_RESOLVED += $(DEP)}\
}

$(DIR_SRC)/%/$(FILENAME_SOURCE_MK):

DEPS := ${sort $(DEPS)}
DEPS_UNRESOLVED := ${filter-out ${sort $(DEPS_RESOLVED)}, $(DEPS)}

${call debug, Deps: $(DEPS)}
${call debug, Deps resolved: $(DEPS_RESOLVED)}
${call debug, Deps unresolved: $(DEPS_UNRESOLVED)}

ifdef DEPS_UNRESOLVED
${call debug, Not all deps resolved - calling recursive make...}
resolve-lib-% libtagion% tagion% test-libtagion%:
	@$(MAKE) $(addprefix resolve-,$(DEPS_UNRESOLVED)) $(MAKECMDGOALS)
	
else
${call debug, All deps successfully resolved}

resolve-%: 
	${call log.kvp, Ensured, $(*)}

# 
# Generate and include gen.source.mk
# 
ALL_SOURCE_MK := ${addprefix $(DIR_SRC)/, $(DEPS)}
ALL_SOURCE_MK := ${addsuffix /$(FILENAME_SOURCE_MK), $(ALL_SOURCE_MK)}

${call debug, Including:}
${call debug.lines, $(ALL_SOURCE_MK)}

-include $(ALL_SOURCE_MK)

$(DIR_SRC)/%/$(FILENAME_SOURCE_MK): source-%
	@

source-%:
	${eval _LOOKUP_PROD := $(LOOKUP) $(LOOKUP_PROD)}
	${eval _LOOKUP_TEST := $(LOOKUP) $(LOOKUP_TEST)}
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LPROD,$(_LOOKUP_PROD),$(DIR_SRC)/$(*)/$(_LPROD)} -o- -of=$(DIR_BUILD_O)/$(subst lib-,libtagion,$(*)).o > $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_MK)
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(_LOOKUP_TEST),$(DIR_SRC)/$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/$(subst lib-,test-libtagion,$(*)).o >> $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_MK)
endif


${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}