include $(DIR_TAGIL)/src/wraps/**/Makefile

# 
# Helper macros
# 
define _locate-d-files
${shell find $(DIR_SRC)/${strip $1}/${strip $2} -name '*.d*'}
endef

define _link-dependency
$(LINKERFLAG)$(DIR_BUILD)/wraps/lib${strip $1}.a
endef

define _cmd_lib_compile
$(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(WRAPS_TO_LINK) $(LDCFLAGS)
endef

define cmd_lib_compile_library
${call _cmd_lib_compile} -c -of$(DIR_BUILD)/libs/libtagion$(@F).a
endef

define cmd_lib_compile_unittest
${call _cmd_lib_compile} $(DEBUG) -unittest -g -main -of$(DIR_BUILD)/tests/libtagion$(@F)
endef

define cmd_lib_compile_bin
${call _cmd_lib_compile} -of$(DIR_BUILD)/bins/libtagion$(@F)
endef

define collect-dependencies
${eval LIBS += $(@F)}
$(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))
$(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))

${eval DFILES := ${foreach LIB, $(LIBS), ${call _locate-d-files, libs, $(LIB)}}}
${eval DFILES += ${foreach WRAP, $(WRAPS), ${call _locate-d-files, wraps, $(WRAP)}}}

${call log.line, All specified dependencies are located}
endef

define collect-dependencies-to-link
${eval WRAPS_TO_LINK += ${foreach WRAP, $(WRAPS), ${call _link-dependency, $(WRAP)}}}
endef

define show-compile-details
${call log.separator}
${call log.kvp, Libs, $(LIBS)}
${call log.kvp, Wraps, $(WRAPS)}

${call log.separator}
${call log.kvp, D Files}
${call log.lines, $(DFILES)}

${call log.separator}
${call log.kvp, Linkings}
${call log.lines, $(WRAPS_TO_LINK)}
endef

define compile
${call log.separator}
${call log.line, Compiling...}
${call log.space}
$(PRECMD)$($1)
${call log.kvp, Compiled, $(DIR_BUILD)/$(@D)s/libtagion$(@F).a}
endef

define run_unittest
${call log.separator}
${call log.line, Testing...}
${call log.space}
$(PRECMD)$(DIR_BUILD)/tests/libtagion$(@F)
endef

# TODO: Add ldc-build-runtime for building phobos and druntime for platforms
# TODO: Add auto cloning wraps
# TODO: Add revision
# TODO: Add check for dependency wraps and libs
# TODO: Add unit tests

# 
# Compile targets to use
# 
ways: 
	$(PRECMD)$(MKDIR) -p $(DIR_BUILD)/wraps
	$(PRECMD)$(MKDIR) -p $(DIR_BUILD)/libs
	$(PRECMD)$(MKDIR) -p $(DIR_BUILD)/bins
	$(PRECMD)$(MKDIR) -p $(DIR_BUILD)/tests

bin/%: show-env-compiler ways ctx/bin/%
	${call log.header, testing lib/$(@F)}
	${call collect-dependencies}
	${call show-compile-details}
	${call compile, cmd_lib_compile_unittest}
	${call log.close}

lib/%: show-env-compiler ways ctx/lib/%
	${call log.header, compiling lib/$(@F)}
	${call collect-dependencies}
	${call show-compile-details}
	${call compile, cmd_lib_compile_library}
	${call log.close}

test/lib/%: ways ctx/lib/%
	${call log.header, testing lib/$(@F)}
	${call collect-dependencies}
	${call show-compile-details}
	${call compile, cmd_lib_compile_unittest}
	${call log.space}
	${call run_unittest}
	${call log.close}


.PHONY: test/lib/%