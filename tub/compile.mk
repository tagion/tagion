# TODO: Add ldc-build-runtime for building phobos and druntime for platforms
# TODO: Add local setup and unittest setup (context)
# TODO: Add revision.di

# Include contexts and wrap Makefiles
CONTEXTS := ${shell find $(DIR_SRC) -name '*context.mk'}

include $(DIR_WRAPS)/**/Makefile
include $(CONTEXTS)

# 
# Helper macros
# 
define locate.d.files
${shell find $(DIR_TAGIL)/${strip $1}/${strip $2} -name '*.d*'}
endef

define link.dependency
$(LINKERFLAG)$(DIR_BUILD)/wraps/lib${strip $1}.a
endef

define cmd.lib.compile
$(PRECMD)$(DC) $(DCFLAGS) $(INCFLAGS) $(DFILES) $(LINKFLAGS) $(LDCFLAGS)
endef

define cmd.lib.compile.library
${call cmd.lib.compile} -c -of$(DIR_BUILD)/libs/libtagion$(@F).a
endef

define cmd.lib.compile.unittest
${call cmd.lib.compile} $(DEBUG) -unittest -g -main -of$(DIR_BUILD)/tests/libtagion$(@F)
endef

define cmd.lib.compile.bin
${call cmd.lib.compile} -of$(DIR_BUILD)/bins/libtagion$(@F)
endef

define collect.dependencies
$(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))
$(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))

${eval DFILES := ${foreach LIB, $(LIBS), ${call locate.d.files, src/libs, $(LIB)}}}
${eval DFILES += ${foreach WRAP, $(WRAPS), ${call locate.d.files, wraps, $(WRAP)}}}

${call log.line, All specified dependencies are resolved}
endef

define collect.dependencies.to.link
${eval LINKFLAGS += ${foreach WRAP, $(WRAPS), ${call link.dependency, $(WRAP)}}}
endef

define show.compile.details
${call log.separator}
${call log.kvp, Libs, $(LIBS)}
${call log.kvp, Wraps, $(WRAPS)}

${call log.separator}
${call log.kvp, D Files}
${call log.lines, $(DFILES)}

${call log.separator}
${call log.kvp, Includes}
${call log.lines, $(INCFLAGS)}

${call log.separator}
${call log.kvp, Links}
${call log.lines, $(LINKFLAGS)}
endef

define compile
${call log.separator}
${call log.line, Compiling...}
${call log.space}
$(PRECMD)${call $1}
endef

define run.unittest
${call log.separator}
${call log.line, Testing...}
${call log.space}
$(PRECMD)$(DIR_BUILD)/tests/libtagion$(@F)
endef

# 
# Target helpers
# 
ctx/lib/%: $(DIR_SRC)/libs/%/context.mk
	${eval LIBS += $(@F)}

ctx/wrap/%: $(DIR_WRAPS)/%/Makefile
	${eval WRAPS += $(@F)}

ways: 
	@$(MKDIR) -p $(DIR_BUILD)/wraps
	@$(MKDIR) -p $(DIR_BUILD)/libs
	@$(MKDIR) -p $(DIR_BUILD)/bins
	@$(MKDIR) -p $(DIR_BUILD)/tests

# 
# Source code add/remove
# 
add/lib/%:
	@cd $(DIR_TAGIL); meta import project src/libs/$(@F) $(GIT_ROOT)/core-lib-$(@F) &> /dev/null
	@cd $(DIR_TAGIL); meta git update

add/bin/%:
	@cd $(DIR_TAGIL); meta import project src/bins/$(@F) $(GIT_ROOT)/core-bin-$(@F) &> /dev/null
	@cd $(DIR_TAGIL); meta git update

add/wrap/%:
	$(PRECMD)git clone $(GIT_ROOT)/core-wrap-$(@F) $(DIR_WRAPS)/$(@F)	

# 
# Compile targets to use
# 
bin/%: env-compiler ways ctx/bin/%
	${call log.header, testing lib/$(@F)}
	${call collect.dependencies}
	${call show.compile.details}
	${call compile, cmd.lib.compile.unittest}
	${call log.kvp, Compiled, $(DIR_BUILD)/$(@D)s/$(@F)}
	${call log.close}

lib/%: env-compiler ways ctx/lib/%
	${call log.header, compiling lib/$(@F)}
	${call collect.dependencies}
	${call show.compile.details}
	${call compile, cmd.lib.compile.library}
	${call log.kvp, Compiled, $(DIR_BUILD)/$(@D)s/libtagion$(@F).a}
	${call log.close}

test/lib/%: ways ctx/lib/%
	${call log.header, testing lib/$(@F)}
	${call collect.dependencies}
	${call collect.dependencies.to.link}
	${call show.compile.details}
	${call compile, cmd.lib.compile.unittest}
	${call log.space}
	${call run.unittest}
	${call log.close}


.PHONY: test/lib/% lib/% bin/%