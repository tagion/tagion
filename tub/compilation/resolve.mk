
# DIRS_LIBS := ${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}

# Delete all deps and errors

# ${foreach LIB_TARGET,$(COMPILE_UNIT_LIB_DIRS),\
# 	${info making command for $(LIB_TARGET)}\
# 	${eval DIRS_LIBS += $(DIR_SRC)/$(LIB_TARGET)}\
# 	${shell ldc2 ${addprefix -I, $(DIRS_LIBS)}\
# 		--makedeps $(DIR_SRC)/$(LIB_TARGET)/**/*.d -o-\
# 		-of=$(DIR_BUILD)/.tmp/libtagion${subst lib-,,$(LIB_TARGET)}.o\
# 		2> $(DIR_SRC)/$(LIB_TARGET)/error.mk\
# 		1> $(DIR_SRC)/$(LIB_TARGET)/deps.mk\
# 	}\
# 	${shell }
# }

${eval ${call debug.open, MAKE RESOLVE - $(MAKECMDGOALS)}}

${eval ${call debug, RESOLVE_UNIT_TARGETS: $(RESOLVE_UNIT_TARGETS)}}

${foreach RESOLVE_UNIT_TARGET,$(RESOLVE_UNIT_TARGETS),\
	${eval DEPS += $(subst resolve-,,$(RESOLVE_UNIT_TARGET))}\
}

${foreach DEP,$(DEPS),\
	${eval ${call including $(DEP) context}}\
	${eval include $(DIR_SRC)/$(DEP)/context.mk}\
	${eval DEPS_RESOLVED += $(DEP)}\
}

DEPS_UNRESOLVED := ${filter-out $(sort $(DEPS_RESOLVED)), $(sort $(DEPS))}

${eval ${call debug, Deps:            $(DEPS)}}
${eval ${call debug, Deps Resolved:   $(DEPS_RESOLVED)}}
${eval ${call debug, Deps Unresolved: $(DEPS_UNRESOLVED)}}

ifdef DEPS_UNRESOLVED
${eval ${call debug, Not all deps resolved, calling recursive make...}}
resolve-lib-%:
	$(MAKE) $(addprefix resolve-,$(DEPS_UNRESOLVED)) $(MAKECMDGOALS)
else
${eval ${call debug, All deps successfully resolved}}
resolve-lib-%:
	@echo resollved all $(*)
endif

${eval ${call debug.close, MAKE RESOLVE - $(MAKECMDGOALS)}}