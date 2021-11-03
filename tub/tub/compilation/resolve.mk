${eval ${call debug.open, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}

ifeq ($(MAKELEVEL),0)
${shell rm -f $(DIR_SRC)/**/$(FILENAME_SOURCE_PROD_MK) || true}
${shell rm -f $(DIR_SRC)/**/$(FILENAME_SOURCE_TEST_MK) || true}
endif

DEPS := ${sort $(DEPS)}
DEPS := $(subst test-,,$(DEPS))

${call debug, DEPS: $(DEPS)}

${foreach DEP,$(DEPS),\
	${call debug, Including $(DEP) context...}\
	${eval include $(DIR_SRC)/$(DEP)/context.mk}\
	${eval DEPS_RESOLVED += $(DEP)}\
}

$(DIR_SRC)/%/$(FILENAME_SOURCE_PROD_MK):

DEPS := ${sort $(DEPS)}
DEPS_UNRESOLVED := ${filter-out ${sort $(DEPS_RESOLVED)}, $(DEPS)}

${call debug, Deps: $(DEPS)}
${call debug, Deps resolved: $(DEPS_RESOLVED)}
${call debug, Deps unresolved: $(DEPS_UNRESOLVED)}

ifdef DEPS_UNRESOLVED
${call debug, Not all deps resolved - calling recursive make...}
libtagion% tagion% test-libtagion%:
	${call log.kvp, Recursive Make, ${addprefix resolve-,$(DEPS_UNRESOLVED)} $(MAKECMDGOALS)}
	@$(MAKE) ${addprefix resolve-,$(DEPS_UNRESOLVED)} $(MAKECMDGOALS)

resolve-%:
	@

else
${call debug, All deps successfully resolved}

resolve-%: 
	${call log.kvp, Ensured, $(*)}

# 
# Generate and include gen.<mode>.source.mk
# 
ALL_SOURCE_MK_BASE := ${addprefix $(DIR_SRC)/, $(DEPS)}
ALL_SOURCE_MK := ${addsuffix /$(FILENAME_SOURCE_PROD_MK), $(ALL_SOURCE_MK_BASE)}
ALL_SOURCE_MK += ${addsuffix /$(FILENAME_SOURCE_TEST_MK), $(ALL_SOURCE_MK_BASE)}

${call debug, Including:}
${call debug.lines, $(ALL_SOURCE_MK)}

-include $(ALL_SOURCE_MK)

$(DIR_SRC)/%/$(FILENAME_SOURCE_PROD_MK): source-%
	@

source-%:
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LPROD,$(LOOKUP) $(LOOKUP_PROD),$(DIR_SRC)/$(*)/$(_LPROD)} -o- -of=$(DIR_BUILD_O)/$(subst lib-,libtagion,$(*)).o > $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_PROD_MK)
	@echo "" >> $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_PROD_MK)
	${eval _DEPS_O_$* := ${shell ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(LOOKUP) $(LOOKUP_PROD),$(DIR_SRC)/$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/$(subst lib-,test-libtagion,$(*)).o | grep $(DIR_SRC)}}
	${eval _DEPS_O_$* := ${subst $(DIR_SRC)/,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst /,.dir ,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${filter lib-%,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst .dir,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${sort $(_DEPS_O_$*)}}
	@echo $(DIR_BUILD_LIBS_STATIC)/$(subst lib-,libtagion,$(*)).a: $(foreach _DEP_O,$(_DEPS_O_$*),$(DIR_BUILD_O)/$(subst lib-,test-libtagion,$(_DEP_O)).o ) >> $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_PROD_MK)
	
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(LOOKUP) $(LOOKUP_TEST),$(DIR_SRC)/$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/$(subst lib-,test-libtagion,$(*)).o > $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_TEST_MK)
	@echo "" >> $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_PROD_MK)
	${eval _DEPS_O_$* := ${shell ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(LOOKUP) $(LOOKUP_TEST),$(DIR_SRC)/$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/$(subst lib-,test-libtagion,$(*)).o | grep $(DIR_SRC)}}
	${eval _DEPS_O_$* := ${subst $(DIR_SRC)/,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst /,.dir ,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${filter lib-%,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst .dir,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${sort $(_DEPS_O_$*)}}
	@echo $(DIR_BUILD_BINS)/test-$(subst lib-,libtagion,$(*)): $(foreach _DEP_O,$(_DEPS_O_$*),$(DIR_BUILD_O)/$(subst lib-,test-libtagion,$(_DEP_O)).o ) >> $(DIR_SRC)/$(*)/$(FILENAME_SOURCE_TEST_MK)
endif

${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}