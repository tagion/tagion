-include ${shell find $(DIR_SRC) -name '*context.mk'}

# TODO: Restore unittests support (compile and run separately)
# TODO: Restore binary building
# TODO: Try only include modules from .ctx declarations
# TODO: Improve ways handling

# TODO: Add revision.di
# TODO: Add ldc-build-runtime for building phobos and druntime for platforms

DIRS_LIBS := ${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}

# 
# Creating required directories
# 
WAYS_PERSISTENT += $(DIR_BUILD)/.way
WAYS += $(DIR_BUILD)/libs/static/.way
WAYS += $(DIR_BUILD)/libs/o/.way
WAYS += $(DIR_BUILD)/tests/.way
WAYS += $(DIR_BUILD)/bins/.way
%/.way:
	$(PRECMD)mkdir -p $(*)
	$(PRECMD)touch $(*)/.way
	$(PRECMD)rm $(*)/.way

ways: $(WAYS) $(WAYS_PERSISTENT)

# 
# Target shortcuts
# 
%.o: | %.ctx $(DIR_BUILD)/libs/o/%.o
	${eval OBJS += $(*)}

lib-%: $(DIR_BUILD)/libs/static/%.a
	@

bin-%: | bin/%.ctx $(DIR_BUILD)/bins/%
	@

testlib-%: | $(DIR_BUILD)/tests/%
	$(PRECMD)$(DIR_BUILD)/tests/$(*)
	${call log.close}

# 
# Targets
# 
$(DIR_BUILD)/libs/static/%.a: | ways %.o
	${call define.parallel}

	${eval _ARCHIVES := ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/o/$(OBJ).o}}
	${eval _ARCHIVES += ${foreach WRAP_STATIC, $(WRAPS_STATIC), $(WRAP_STATIC)}}
	
	${eval _TARGET := $(@D)/libtagion$(*).a}

	${call execute.ifnot.parallel, ${call show.archive.details, archive - $(*)}}

	$(PRECMD)ar cr $(_TARGET) $(_ARCHIVES)
	${call log.kvp, Archived, $(_TARGET)}
	${call execute.ifnot.parallel, ${call log.close}}

$(DIR_BUILD)/libs/o/%.o: | ways
	${call define.parallel}

	${eval INCFLAGS := ${foreach DIR_LIB, $(DIRS_LIBS), -I$(DIR_TUB_ROOT)/$(DIR_LIB)}}
	${eval INFILES := ${call find.files, ${DIR_SRC}/lib-$(*), *.d}}
	
	${eval _TARGET := $(@)}

	${eval _DCFLAGS := $(DCFLAGS)}
	${eval _DCFLAGS += -c}
	${eval _DCFLAGS += -of$(_TARGET)}

	${eval _LDCFLAGS := $(LDCFLAGS)}
	
	${call execute.ifnot.parallel, ${call show.compile.details, compile - $(*)}}

	$(PRECMD)$(DC) $(_DCFLAGS) $(INFILES) $(INCFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(_TARGET)}
	${call execute.ifnot.parallel, ${call log.close}}

$(DIR_BUILD)/tests/%: | ways %.ctx
	${call define.parallel}

	${eval INCFLAGS := ${foreach DIR_LIB, $(DIRS_LIBS), -I$(DIR_TUB_ROOT)/$(DIR_LIB)}}
	${eval INFILES := ${call find.files, $(DIR_SRC)/lib-$(*), *.d}}
	${eval INFILES += ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/o/$(OBJ).o}}
	
	${eval _TARGET := $(@)}

	${eval _DCFLAGS := $(DCFLAGS)}
	${eval _DCFLAGS += -unittest}
	${eval _DCFLAGS += -main}
	${eval _DCFLAGS += -g}
	${eval _DCFLAGS += -of$(_TARGET)}

	${eval _LDCFLAGS := $(LDCFLAGS)}
	${eval _LDCFLAGS += ${foreach WRAP_STATIC, $(WRAPS_STATIC), -L$(WRAP_STATIC)}}
	
	${call execute.ifnot.parallel, ${call show.compile.details, test - $(*)}}

	$(PRECMD)$(DC) $(_DCFLAGS) $(INFILES) $(INCFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(_TARGET)}
	${call execute.ifnot.parallel, ${call log.close}}

# 
# Clean
# 
clean:
	${call log.header, cleaning WAYS}
	${eval CLEAN_DIRS := ${foreach WAY, $(WAYS), ${dir $(WAY)}}}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}

clean/all:
	${call log.header, cleaning WAYS and WAYS_PERSISTENT}
	${eval CLEAN_DIRS := ${foreach WAY, $(WAYS), ${dir $(WAY)}}}
	${eval CLEAN_DIRS += ${foreach WAY, $(WAYS_PERSISTENT), ${dir $(WAY)}}}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}

# 
# Helper macros
# 
define find.files
${shell find ${strip $1} -not -path "$(SOURCE_FIND_EXCLUDE)" -name '${strip $2}'}
endef

define define.parallel
${eval PARALLEL := ${shell [[ "$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1}}
endef

define execute.ifnot.parallel
${if $(PARALLEL),,$1}
endef

define execute.if.parallel
${if $(PARALLEL),$1,}
endef


define show.compile.details
${call log.header, ${strip $1}}

${if $(WRAPS_STATIC),${call log.kvp, WRAPS_STATIC}}
${if $(WRAPS_STATIC),${call log.lines, $(WRAPS_STATIC)}}

${if $(OBJS),${call log.kvp, OBJS, $(OBJS)}}

${call log.kvp, DC, $(DC)}
${call log.kvp, DCFLAGS, $(_DCFLAGS)}

${call log.kvp, INCFLAGS}
${call log.lines, $(INCFLAGS)}

${call log.kvp, INFILES}
${call log.lines, $(INFILES)}

${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}
${if $(LATEFLAGS),${call log.kvp, LATEFLAGS, $(LATEFLAGS)},}

${call log.space}
endef

define show.archive.details
${call log.header, ${strip $1}}
${call log.kvp, Including}
${call log.lines, $(_ARCHIVES)}

${call log.space}
endef