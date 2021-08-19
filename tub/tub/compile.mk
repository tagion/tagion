# Include contexts and wrap Makefiles
-include $(DIR_WRAPS)/**/Makefile
-include ${shell find $(DIR_SRC) -name '*context.mk'}

# TODO: Add revision.di

# TODO: Add local setup and unittest setup (context)
# -include ${shell find $(DIR_SRC) -name '*local.mk'}

# TODO: Add ldc-build-runtime for building phobos and druntime for platforms

LIBDIRS := ${shell ls -d src/libs/*/}
INCFLAGS += ${foreach LIBDIR, $(LIBDIRS), -I$(DIR_TUB_ROOT)/$(LIBDIR)}

# 
# Helper macros
# 
define find.files
${shell find ${strip $1} -not -path "$(SOURCE_FIND_EXCLUDE)" -name '${strip $2}'}
endef

define collect.dependencies.to.link
${eval LINKFLAGS += ${foreach WRAPLIB, $(WRAPLIBS), ${call link.dependency, $(WRAPLIB)}}}
endef

define show.compile.details
${call log.kvp, Dependencies, $(OBJS)}
${call log.kvp, Wraps, $(WRAPS)}

${call log.separator}
${call log.kvp, DC, $(DC)}

${call log.separator}
${call log.kvp, DCFLAGS}
${call log.lines, $(DCFLAGS)}

${call log.separator}
${call log.kvp, INCFLAGS}
${call log.lines, $(INCFLAGS)}

${call log.separator}
${call log.kvp, INFILES}
${call log.lines, $(INFILES)}

${call log.separator}
${call log.kvp, LDCFLAGS}
${call log.lines, $(LDCFLAGS)}

${call log.separator}
${call log.kvp, LATEFLAGS}
${call log.lines, $(LATEFLAGS)}
endef

define compile
${call log.separator}
${call log.line, Compiling...}
${call log.space}
$(PRECMD)${call cmd.compile, $1}
endef

define run
${call log.separator}
${call log.line, Running...}
${call log.space}
$(PRECMD)$(DIR_BUILD)/${strip $1}
endef

# 
# Creating required directories
# 
ways: WAYS += $(DIR_BUILD)/libs/static $(DIR_BUILD)/libs/o $(DIR_BUILD)/bins
ways: 
	${foreach WAY, $(WAYS), ${shell mkdir -p $(WAY)}}

# 
# Target helpers
# 
# ctx/lib/%: $(DIR_SRC)/libs/%/context.mk

# ctx/wrap/%: $(DIR_WRAPS)/%/Makefile wrap/%
# 	@

%.o: | %.ctx $(DIR_BUILD)/libs/o/%.o
	${eval OBJS += $(*)}

%.a: $(DIR_BUILD)/libs/static/%.a
	@

$(DIR_BUILD)/libs/static/%.a: | ways %.o
	$(PRECMD)ar cr $(DIR_BUILD)/libs/static/libtagion$(*).a ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/o/$(OBJ).o}
	${call log.kvp, Archived, $(@D)/libtagion$(*).a}

$(DIR_BUILD)/libs/o/%.o: ways
	${eval CMD := $(PRECMD)}
	${eval CMD += $(DC)}
	${eval CMD += $(DCFLAGS)}
	${eval CMD += -c}
	${eval CMD += -of$(DIR_BUILD)/libs/o/$(*).o}
	${eval CMD += $(INCFLAGS)}
	${eval CMD += ${call find.files, $(DIR_TUB_ROOT)/src/libs/$(*), *.d}}
	${eval CMD += $(LDCFLAGS)}
	$(CMD)
	${call log.kvp, Compiled, $(DIR_BUILD)/libs/o/$(*).o}

# 
# Clean build directory
# 
clean:
	${call log.lin, cleaning ./builds}
	@rm -rf $(DIR_BUILD)/*