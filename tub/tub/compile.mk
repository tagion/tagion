# TODO: Add ldc-build-runtime for building phobos and druntime for platforms
# TODO: Add local setup and unittest setup (context)
# TODO: Add revision.di

# Include contexts and wrap Makefiles
-include $(DIR_WRAPS)/**/Makefile
-include ${shell find $(DIR_SRC) -name '*context.mk'}

# 
# Helper macros
# 
define find.files
${shell find ${strip $1} -not -path "$(SOURCE_FIND_EXCLUDE)" -name '${strip $2}'}
endef

define cmd.compile
$(PRECMD)$(DC) $(DCFLAGS) $(strip $1) ${INCFLAGS} $(INFILES) $(LDCFLAGS) $(LATEFLAGS)
endef

define collect.dependencies
$(eval LIBS := $(foreach X, $(LIBS), $(eval LIBS := $(filter-out $X, $(LIBS)) $X))$(LIBS))
$(eval WRAPS := $(foreach X, $(WRAPS), $(eval WRAPS := $(filter-out $X, $(WRAPS)) $X))$(WRAPS))

${eval INFILES += ${foreach LIB, $(LIBS), ${call locate.d.files, $(DIR_TUB_ROOT)/src/libs/$(LIB)}}}
${eval INFILES += ${foreach LIB, $(LIBS), ${call locate.di.files, $(DIR_TUB_ROOT)/src/libs/$(LIB)}}}
${eval INFILES += ${foreach WRAP, $(WRAPS), ${call locate.d.files, $(DIR_TUB_ROOT)/wraps/$(WRAP)}}}
${eval INFILES += ${foreach WRAP, $(WRAPS), ${call locate.di.files, $(DIR_TUB_ROOT)/wraps/$(WRAP)}}}
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
ways: WAYS += $(DIR_BUILD)/libs $(DIR_BUILD)/bins $(DIR_BUILD)/libs/.obj
ways: 
	${foreach WAY, $(WAYS), ${shell mkdir -p $(WAY)}}

# 
# Target helpers
# 
# ctx/lib/%: $(DIR_SRC)/libs/%/context.mk

# ctx/wrap/%: $(DIR_WRAPS)/%/Makefile wrap/%
# 	@

ctx/%:
	${eval OBJS += $(*)}

o/%: | ctx/% $(DIR_BUILD)/libs/.obj/%.o
	@

lib/%: $(DIR_BUILD)/libs/%.a
	@

$(DIR_BUILD)/libs/%.a: | ways o/%
	${eval ARCHIVE_OBJS := ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/.obj/$(OBJ).o}}
	$(PRECMD)ar cr $(DIR_BUILD)/libs/libtagion$(*).a $(ARCHIVE_OBJS)
	${call log.kvp, Compiled, $(@D)/libtagion$(*).a}

$(DIR_BUILD)/libs/.obj/%.o: ways
	${eval INCFLAGS += ${foreach OBJ, $(OBJS), -I${DIR_SRC}/libs/$(OBJ)/}}
	${eval INCFLAGS += ${foreach WRAP, $(WRAPS), -I${DIR_WRAPS}/$(WRAP)/}}
	${eval INFILES := ${call find.files, $(DIR_TUB_ROOT)/src/libs/$(*), *.d}}
	${call cmd.compile, -c -of$(DIR_BUILD)/libs/.obj/$(*).o}
	${call log.kvp, Compiled, $(DIR_BUILD)/libs/.obj/$(*).o}

# lib/%: ctx/lib/%
# 	${call log.header, compiling lib $(*)}
# 	${eval ARCHIVE_OBJS := ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/.obj/$(OBJ).o}}
# 	$(PRECMD)ar cr $(DIR_BUILD)/libs/libtagion$(*).a $(ARCHIVE_OBJS)
# 	${call log.kvp, Compiled, $(DIR_BUILD)/$(@D)s/libtagion$(@F).a}
# 	${call log.close}

# test/lib/%: env/compiler ways ctx/lib/%
# 	${eval TARGET := $(@F)}
# 	${call log.header, testing lib/$(@F)}
# 	${call collect.dependencies}
# 	${call collect.dependencies.to.link}
# 	${call show.compile.details}
# 	${call compile, cmd.compile.unittest}
# 	${call log.space}
# 	${call run}
# 	${call log.close}


# 
# Clean build directory
# 
clean:
	${call log.lin, cleaning ./builds}
	@rm -rf $(DIR_BUILD)/*