# TODO: Add revision.di
# TODO: Add ldc-build-runtime for building phobos and druntime for platforms

DIRS_LIBS := ${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}

# 
# Creating required directories
# 

%/.way:
	$(PRECMD)mkdir -p $(*)
	$(PRECMD)touch $(*)/.way
	$(PRECMD)rm $(*)/.way

WAYS_PERSISTENT += $(DIR_BUILD)/.way
WAYS += $(DIR_BUILD_TEMP)/o/.way
WAYS += $(DIR_BUILD)/libs/.way
WAYS += $(DIR_BUILD)/bins/.way

ways: $(WAYS) $(WAYS_PERSISTENT)

# 
# Target shortcuts
# 
# tagion%: $(DIR_BUILD)/bins/tagion%
# 	@

# libtagion%.o: $(DIR_BUILD)/libs/o/libtagion%.o
# 	${eval OBJS += $(*)}

# libtagion%.a: $(DIR_BUILD)/libs/static/libtagion%.a
# 	@

# libtagion%: libtagion%.a
# 	@

# test_libtagion%: $(DIR_BUILD)/tests/test_libtagion%
# 	@

# runtest_libtagion%: test_libtagion%
# 	${call log.header, run test_libtagion$(*)}
# 	$(PRECMD)$(DIR_BUILD)/tests/test_libtagion$(*)
# 	${call log.close}

# 
# Targets
# 
# $(DIR_BUILD)/libs/static/libtagion%.a: | ways libtagion%.o
# 	${call define.parallel}

# 	${eval _ARCHIVES := ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/o/libtagion$(OBJ).o}}
# 	${eval _ARCHIVES += ${foreach WRAP_STATIC, $(WRAPS_STATIC), $(WRAP_STATIC)}}
	
# 	${eval _TARGET := $(@)}

# 	${call execute.ifnot.parallel, ${call show.archive.details, archive - $(@F)}}

# 	$(PRECMD)ar cr $(_TARGET) $(_ARCHIVES)
# 	${call log.kvp, Archived, $(_TARGET)}
# 	${call execute.ifnot.parallel, ${call log.close}}

# $(DIR_BUILD)/libs/o/libtagion%.o: | ways
# 	${call define.parallel}

# 	${eval INCFLAGS := ${foreach DIR_LIB, $(DIRS_LIBS), -I$(DIR_TUB_ROOT)/$(DIR_LIB)}}
# 	${eval INFILES := ${call find.files, ${DIR_SRC}/lib-$(*), *.d}}
# 	${eval INFILES += ${foreach WRAP_HEADER, $(WRAPS_HEADERS), $(WRAP_HEADER)}}
	
# 	${eval _TARGET := $(@)}

# 	${eval _DCFLAGS := $(DCFLAGS)}
# 	${eval _DCFLAGS += -c}
# 	${eval _DCFLAGS += -of$(_TARGET)}

# 	${eval _LDCFLAGS := $(LDCFLAGS)}
	
# 	${call execute.ifnot.parallel, ${call show.compile.details, compile - $(@F)}}

# 	$(PRECMD)$(DC) $(_DCFLAGS) $(INFILES) $(INCFLAGS) $(_LDCFLAGS)
# 	${call log.kvp, Compiled, $(_TARGET)}
# 	${call execute.ifnot.parallel, ${call log.close}}

# $(DIR_BUILD)/tests/test_libtagion%: | ways
# 	${call define.parallel}

# 	${eval _OBJS := ${subst $(*),,$(OBJS)}}
# 	${eval _WRAPS := $(WRAPS)}
	
# 	${eval INCFLAGS := ${foreach DIR_LIB, $(DIRS_LIBS), -I$(DIR_TUB_ROOT)/$(DIR_LIB)}}
# 	${eval INFILES := ${call find.files, $(DIR_SRC)/lib-$(*), *.d}}
# 	${eval INFILES += ${foreach OBJ, $(_OBJS), $(DIR_BUILD)/libs/o/libtagion$(OBJ).o}}
# 	${eval INFILES += ${foreach WRAP_HEADER, $(WRAPS_HEADERS), $(WRAP_HEADER)}}
# 	${eval INFILES += ${foreach WRAP_STATIC, $(WRAPS_STATIC), $(WRAP_STATIC)}}
	
# 	${eval _TARGET := $(@)}

# 	${eval _DCFLAGS := $(DCFLAGS)}
# 	${eval _DCFLAGS += -unittest}
# 	${eval _DCFLAGS += -main}
# 	${eval _DCFLAGS += -g}
# 	${eval _DCFLAGS += -of$(_TARGET)}

# 	${eval _LDCFLAGS := $(LDCFLAGS)}
	
# 	${call execute.ifnot.parallel, ${call show.compile.details, test - $(@F)}}

# 	$(PRECMD)$(DC) $(_DCFLAGS) $(INFILES) $(INCFLAGS) $(_LDCFLAGS)
# 	${call log.kvp, Compiled, $(_TARGET)}
# 	${call execute.ifnot.parallel, ${call log.close}}

# $(DIR_BUILD)/bins/tagion%: | ways
# 	${call define.parallel}

# 	${eval _OBJS := ${subst $(*),,$(OBJS)}}
# 	${eval _WRAPS := $(WRAPS)}
	
# 	${eval INCFLAGS := ${foreach DIR_LIB, $(DIRS_LIBS), -I$(DIR_TUB_ROOT)/$(DIR_LIB)}}
# 	${eval INFILES := ${call find.files, $(DIR_SRC)/bin-$(*), *.d}}
# 	${eval INFILES += ${foreach OBJ, $(_OBJS), $(DIR_BUILD)/libs/o/libtagion$(OBJ).o}}
# 	${eval INFILES += ${foreach WRAP_HEADER, $(WRAPS_HEADERS), $(WRAP_HEADER)}}
# 	${eval INFILES += ${foreach WRAP_STATIC, $(WRAPS_STATIC), $(WRAP_STATIC)}}
	
# 	${eval _TARGET := $(@)}

# 	${eval _DCFLAGS := $(DCFLAGS)}
# 	${eval _DCFLAGS += -of$(_TARGET)}

# 	${eval _LDCFLAGS := $(LDCFLAGS)}
	
# 	${call execute.ifnot.parallel, ${call show.compile.details, compile - $(@F)}}

# 	$(PRECMD)$(DC) $(_DCFLAGS) $(INFILES) $(INCFLAGS) $(_LDCFLAGS)
# 	${call log.kvp, Compiled, $(_TARGET)}
# 	${call execute.ifnot.parallel, ${call log.close}}
