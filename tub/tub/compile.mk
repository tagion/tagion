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
${shell find ${strip $1} $(SOURCEFLAGS) -name '*.d'}
endef

define locate.di.files
${shell find ${strip $1} $(SOURCEFLAGS) -name '*.di'}
endef

define link.dependency
${strip $1}
endef

define cmd.lib.compile
$(PRECMD)$(DC) $(DCFLAGS) $(DFILES) ${LINKFLAGS} $(LDCFLAGS) $(OTHERFLAGS)
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

${eval DFILES += ${foreach LIB, $(LIBS), ${call locate.d.files, $(DIR_TUB_ROOT)/src/libs/$(LIB)}}}
${eval DFILES += ${foreach LIB, $(LIBS), ${call locate.di.files, $(DIR_TUB_ROOT)/src/libs/$(LIB)}}}
${eval DFILES += ${foreach WRAP, $(WRAPS), ${call locate.d.files, $(DIR_TUB_ROOT)/wraps/$(WRAP)}}}
${eval DFILES += ${foreach WRAP, $(WRAPS), ${call locate.di.files, $(DIR_TUB_ROOT)/wraps/$(WRAP)}}}
endef

define collect.dependencies.to.link
${eval LINKFLAGS += ${foreach WRAPLIB, $(WRAPLIBS), ${call link.dependency, $(WRAPLIB)}}}
endef

define show.compile.details
${call log.kvp, Target, $(TARGET)}
${call log.kvp, Libs, $(LIBS)}
${call log.kvp, Wraps, $(WRAPS)}

${call log.separator}
${call log.kvp, DFILES}
${call log.lines, $(DFILES)}

${call log.separator}
${call log.kvp, DCFLAGS}
${call log.lines, $(DCFLAGS)}

${call log.separator}
${call log.kvp, LINKFLAGS}
${call log.lines, $(LINKFLAGS)}

${call log.separator}
${call log.kvp, LDCFLAGS}
${call log.lines, $(LDCFLAGS)}

${call log.separator}
${call log.kvp, OTHERFLAGS}
${call log.lines, $(OTHERFLAGS)}
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
ctx/bin/%: $(DIR_SRC)/bins/%/context.mk
	@

ctx/lib/%: $(DIR_SRC)/libs/%/context.mk
	${eval LIBS += $(@F)}

ctx/wrap/%: $(DIR_WRAPS)/%/Makefile wrap/%
	@

ways: WAYS += $(DIR_BUILD)/wraps $(DIR_BUILD)/libs $(DIR_BUILD)/bins $(DIR_BUILD)/tests
ways: 
	${foreach WAY, $(WAYS), ${shell mkdir -p $(WAY)}}

# 
# Compile targets to use
# 
bin/%: | env/compiler ways ctx/bin/%
	${eval TARGET := $(@F)}
	${call log.header, testing lib/$(@F)}
	${eval DFILES := ${call locate.d.files, $(DIR_TUB_ROOT)/src/bins/$(TARGET)}}
	${call collect.dependencies}
	${call collect.dependencies.to.link}
	${call show.compile.details}
	${call compile, cmd.lib.compile.bin}
	${call log.kvp, Compiled, $(DIR_BUILD)/$(@D)s/$(@F)}
	${call log.close}

lib/%: | env/compiler ways ctx/lib/%
	${eval TARGET := $(@F)}
	${call log.header, compiling lib/$(@F)}
	${call collect.dependencies}
	${call show.compile.details}
	${call compile, cmd.lib.compile.library}
	${call log.kvp, Compiled, $(DIR_BUILD)/$(@D)s/libtagion$(@F).a}
	${call log.close}

test/lib/%: env/compiler ways ctx/lib/%
	${eval TARGET := $(@F)}
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