# Include contexts and wrap Makefiles
-include ${shell find $(DIR_SRC) -name '*context.mk'}

# TODO: Restore wraps support
# TODO: Restore unittests support (compile and run separately)
# TODO: Restore binary building
# TODO: Simplify dir structure (lib-* bin-*)
# TODO: Add arch to build folder based on env variables

# TODO: Add conditional logger to clean up the logging
# TODO: Add revision.di

# TODO: Add local setup and unittest setup (context)
# -include ${shell find $(DIR_SRC) -name '*local.mk'}

# TODO: Add ldc-build-runtime for building phobos and druntime for platforms


# We include all libs for imports


# 
# Creating required directories
# 
WAYS += $(DIR_BUILD)/.way

%/.way:
	$(PRECMD)mkdir -p $(*)
	$(PRECMD)touch $(*)/.way
	$(PRECMD)rm $(*)/.way

ways: $(WAYS)

# 
# Target helpers
# 
# ctx/wrap/%: $(DIR_WRAPS)/%/Makefile wrap/%
# 	@

lib/%: $(DIR_BUILD)/libs/static/%.a
	@

%.o: | %.ctx $(DIR_BUILD)/libs/o/%.o
	${eval OBJS += $(*)}

$(DIR_BUILD)/libs/static/%.a: | $(DIR_BUILD)/libs/static/.touch %.o
	${eval ARCHIVE := ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/o/$(OBJ).o}}
	${eval PARALLEL := ${shell [[ "$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1}}
	${if $(PARALLEL), , ${call log.header, archiving $(*).a}}
	${if $(PARALLEL), , ${call show.archive.details}}
	$(PRECMD)ar cr $(DIR_BUILD)/libs/static/libtagion$(*).a $(ARCHIVE)
	${if $(PARALLEL), , ${call log.separator}}
	${call log.kvp, Archived, $(@D)/libtagion$(*).a}
	${if $(PARALLEL), , ${call log.close}}

$(DIR_BUILD)/libs/o/%.o: $(DIR_BUILD)/libs/o/.touch
	${eval LIBDIRS := ${shell ls -d src/libs/*/ | grep -v $(*)}}
	${eval INCFLAGS += ${foreach LIBDIR, $(LIBDIRS), -I$(DIR_TUB_ROOT)/$(LIBDIR)}}
	${eval INFILES := ${call find.files, ${DIR_LIBS}/$(*), *.d}}
	${eval OUTPUTFLAGS := -c}
	${eval OUTPUTFLAGS += -of$(DIR_BUILD)/libs/o/$(*).o}
	${eval COMPILE := $(PRECMD)}
	${eval COMPILE += $(DC)}
	${eval COMPILE += $(DCFLAGS)}
	${eval COMPILE += $(OUTPUTFLAGS)}
	${eval COMPILE += $(INFILES)}
	${eval COMPILE += $(INCFLAGS)}
	${eval COMPILE += $(LDCFLAGS)}
	${eval PARALLEL := ${shell [[ "$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1}}
	${if $(PARALLEL), , ${call log.header, compiling $(*).o}}
	${if $(PARALLEL), , ${call show.compile.details}}
	$(COMPILE)
	${call log.kvp, Compiled, $(DIR_BUILD)/libs/o/$(*).o}
	${if $(PARALLEL), , ${call log.close}}

# 
# Clean build directory
# 
clean:
	${call log.header, cleaning}
	${eval CLEAN_DIRS := ${foreach WAY, $(WAYS), ${dir $(WAY)}}}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}

# 
# Helper macros
# 
define find.files
${shell find ${strip $1} -not -path "$(SOURCE_FIND_EXCLUDE)" -name '${strip $2}'}
endef

define show.compile.details
${call log.kvp, DC, $(DC)}

${call log.separator}
${call log.kvp, DCFLAGS}
${call log.lines, $(DCFLAGS)}

${call log.separator}
${call log.kvp, OUTPUTFLAGS}
${call log.lines, $(OUTPUTFLAGS)}

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

define show.archive.details
${call log.kvp, Including}
${call log.lines, $(ARCHIVE)}

${call log.separator}
${call log.kvp, Linking}
${call log.lines, $(WRAPS)}
endef