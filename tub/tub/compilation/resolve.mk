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

DEPS := ${sort $(DEPS)}
DEPS_UNRESOLVED := ${filter-out ${sort $(DEPS_RESOLVED)}, $(DEPS)}

${call debug, Deps: $(DEPS)}
${call debug, Deps resolved: $(DEPS_RESOLVED)}
${call debug, Deps unresolved: $(DEPS_UNRESOLVED)}

ifdef DEPS_UNRESOLVED
${call debug, Not all deps resolved - calling recursive make...}

libtagion% tagion% test-libtagion%:
	@$(MAKE) ${addprefix resolve-,$(DEPS_UNRESOLVED)} $(MAKECMDGOALS)

resolve-%:
	${call log.line,}

else
${call debug, All deps successfully resolved}

resolve-%: 
	${call log.line,}

# 
# Generate and include gen.<mode>.source.mk
# 
LIB_SOURCE_MK_BASE := ${addprefix $(DIR_SRC)/,${filter lib-%,${DEPS}}}
BIN_SOURCE_MK_BASE := ${addprefix $(DIR_SRC)/,${filter bin-%,${DEPS}}}

LIB_SOURCE_MK := ${addsuffix /$(FILENAME_SOURCE_PROD_MK),$(LIB_SOURCE_MK_BASE)}
LIB_SOURCE_MK += ${addsuffix /$(FILENAME_SOURCE_TEST_MK),$(LIB_SOURCE_MK_BASE)}
BIN_SOURCE_MK := ${addsuffix /$(FILENAME_SOURCE_PROD_MK),$(BIN_SOURCE_MK_BASE)}

${call debug, Including:}
${call debug.lines, $(BIN_SOURCE_MK)}
${call debug.lines, $(LIB_SOURCE_MK)}

-include $(BIN_SOURCE_MK)
-include $(LIB_SOURCE_MK)

$(DIR_SRC)/bin-%/$(FILENAME_SOURCE_PROD_MK): source-bin-%
	@

$(DIR_SRC)/lib-%/$(FILENAME_SOURCE_TEST_MK) $(DIR_SRC)/lib-%/$(FILENAME_SOURCE_PROD_MK): source-lib-%
	@

# TODO: Refactor and optimize source-* targets
source-bin-%:
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LPROD,$(LOOKUP) $(LOOKUP_PROD),$(DIR_SRC)/bin-$(*)/$(_LPROD)} -o- -of=$(DIR_BUILD_O)/tagion$(*).o > $(DIR_SRC)/bin-$(*)/$(FILENAME_SOURCE_PROD_MK)
	@echo "" >> $(DIR_SRC)/bin-$(*)/$(FILENAME_SOURCE_PROD_MK)
	${eval _DEPS_O_$* := ${shell ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(LOOKUP) $(LOOKUP_PROD),$(DIR_SRC)/bin-$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/tagion$(*).o | grep $(DIR_SRC)}}
	${eval _DEPS_O_$* := ${subst $(DIR_SRC)/,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst /,.dir ,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${filter lib-%,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst .dir,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${sort $(_DEPS_O_$*)}}
	@echo $(DIR_BUILD_BINS)/tagion$(*): $(foreach _DEP_O,$(_DEPS_O_$*),$(DIR_BUILD_O)/$(subst lib-,libtagion,$(_DEP_O)).o ) >> $(DIR_SRC)/bin-$(*)/$(FILENAME_SOURCE_PROD_MK)

source-lib-%:
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LPROD,$(LOOKUP) $(LOOKUP_PROD),$(DIR_SRC)/lib-$(*)/$(_LPROD)} -o- -of=$(DIR_BUILD_O)/libtagion$(*).o > $(DIR_SRC)/lib-$(*)/$(FILENAME_SOURCE_PROD_MK)
	@echo "" >> $(DIR_SRC)/lib-$(*)/$(FILENAME_SOURCE_PROD_MK)
	${eval _DEPS_O_$* := ${shell ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(LOOKUP) $(LOOKUP_PROD),$(DIR_SRC)/lib-$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/libtagion$(*).o | grep $(DIR_SRC)}}
	${eval _DEPS_O_$* := ${subst $(DIR_SRC)/,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst /,.dir ,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${filter lib-%,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst .dir,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${sort $(_DEPS_O_$*)}}
	@echo $(DIR_BUILD_LIBS_STATIC)/libtagion$(*).a: $(foreach _DEP_O,$(_DEPS_O_$*),$(DIR_BUILD_O)/$(subst lib-,libtagion,$(_DEP_O)).o ) >> $(DIR_SRC)/lib-$(*)/$(FILENAME_SOURCE_PROD_MK)
	
	@ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(LOOKUP) $(LOOKUP_TEST),$(DIR_SRC)/lib-$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/test-libtagion$(*).o > $(DIR_SRC)/lib-$(*)/$(FILENAME_SOURCE_TEST_MK)
	@echo "" >> $(DIR_SRC)/lib-$(*)/$(FILENAME_SOURCE_PROD_MK)
	${eval _DEPS_O_$* := ${shell ldc2 ${foreach DEP,$(DEPS),-I$(DIR_SRC)/$(DEP)} --makedeps ${foreach _LTEST,$(LOOKUP) $(LOOKUP_TEST),$(DIR_SRC)/lib-$(*)/$(_LTEST)} -o- -of=$(DIR_BUILD_O)/test-libtagion$(*).o | grep $(DIR_SRC)}}
	${eval _DEPS_O_$* := ${subst $(DIR_SRC)/,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst /,.dir ,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${filter lib-%,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${subst .dir,,$(_DEPS_O_$*)}}
	${eval _DEPS_O_$* := ${sort $(_DEPS_O_$*)}}
	@echo $(DIR_BUILD_BINS)/test-libtagion$(*): $(foreach _DEP_O,$(_DEPS_O_$*),$(DIR_BUILD_O)/$(subst lib-,test-libtagion,$(_DEP_O)).o ) >> $(DIR_SRC)/lib-$(*)/$(FILENAME_SOURCE_TEST_MK)
endif

${eval ${call debug.close, MAKE RESOLVE LEVEL $(MAKELEVEL) - $(MAKECMDGOALS)}}