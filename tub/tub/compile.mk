# TODO: Add ldc-build-runtime for building phobos and druntime for platforms
# TODO: Add local setup and unittest setup (context)
# TODO: Add revision.di

# Include contexts and wrap Makefiles
CONTEXTS := ${shell find $(DIR_SRC) -name '*context.mk'}

-include $(DIR_WRAPS)/**/Makefile
-include $(CONTEXTS)

# 
# Helper macros
# 
define locate.d.files
${shell find ${strip $1} -name '*.d'}
endef

define locate.di.files
${shell find ${strip $1} -name '*.di'}
endef

define link.dependency
$(LINKERFLAG)${strip $1}
endef

define cmd.lib.compile
$(PRECMD)$(DC) $(DCFLAGS) $(DFILES) $(LINKFLAGS) $(LDCFLAGS)
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

${eval DFILES := ${foreach LIB, $(LIBS), ${call locate.d.files, $(DIR_TUB_ROOT)/src/libs/$(LIB)}}}
${eval DFILES += ${foreach LIB, $(LIBS), ${call locate.di.files, $(DIR_TUB_ROOT)/src/libs/$(LIB)}}}
${eval DFILES += ${foreach WRAP, $(WRAPS), ${call locate.d.files, $(DIR_TUB_ROOT)/wraps/$(WRAP)}}}
${eval DFILES += ${foreach WRAP, $(WRAPS), ${call locate.di.files, $(DIR_TUB_ROOT)/wraps/$(WRAP)}}}
endef

define collect.dependencies.to.link
${eval LINKFLAGS += ${foreach WRAPLIB, $(WRAPLIBS), ${call link.dependency, $(WRAPLIB)}}}
endef

define show.compile.details
${call log.kvp, Libs, $(LIBS)}
${call log.kvp, Wraps, $(WRAPS)}

${call log.separator}
${call log.kvp, D Files}
${call log.lines, $(DFILES)}

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

ctx/wrap/%: $(DIR_WRAPS)/%/Makefile wrap/%
	${call log.line, Connecting $(%F) wrapper...}

ways: 
	@$(MKDIR) -p $(DIR_BUILD)
	@$(MKDIR) -p $(DIR_BUILD)/wraps
	@$(MKDIR) -p $(DIR_BUILD)/libs
	@$(MKDIR) -p $(DIR_BUILD)/bins
	@$(MKDIR) -p $(DIR_BUILD)/tests

# 
# Source code cloning
# 
add/lib/%:
	$(PRECMD)git clone $(GIT_ORIGIN)/core-lib-$(@F) $(DIR_LIBS)/$(@F)	

add/bin/%:
	$(PRECMD)git clone $(GIT_ORIGIN)/core-bin-$(@F) $(DIR_BINS)/$(@F)	

add/wrap/%:
	$(PRECMD)git clone $(GIT_ORIGIN)/core-wrap-$(@F) $(DIR_WRAPS)/$(@F)	

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

# 
# Clean build directory
# 
clean:
	${call log.header, cleaning builds}
	${call log.line, Directory to clean:)}
	${call log.line, $(DIR_BUILD)}
	${call log.space}
	${call log.line, Cleaning in 3...}
	@sleep 1
	${call log.line, Cleaning in 2...}
	@sleep 1
	${call log.line, Cleaning in 1...}
	@sleep 1
	${call log.space}
	@rm -rf $(DIR_BUILD)/*
	${call log.line, Build directory is clean!}
	${call log.close}