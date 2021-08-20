# Include contexts and wrap Makefiles
-include $(DIR_WRAPS)/**/Makefile
-include ${shell find $(DIR_SRC) -name '*context.mk'}

# TODO: Add revision.di

# TODO: Add local setup and unittest setup (context)
# -include ${shell find $(DIR_SRC) -name '*local.mk'}

# TODO: Add ldc-build-runtime for building phobos and druntime for platforms


# We include all libs for imports
LIBDIRS := ${shell ls -d src/libs/*/}
# WRAPDIRS := ${shell ls -d src/wraps/*/}
INCFLAGS += ${foreach LIBDIR, $(LIBDIRS), -I$(DIR_TUB_ROOT)/$(LIBDIR)}

# 
# Creating required directories
# 
%/.touch:
	$(PRECMD)mkdir -p $(*)
	$(PRECMD)touch $(*)/.touch

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
	${eval PARALLEL := ${shell [[ "$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1}}
	${if $(PARALLEL), , ${call show.compile.details}}
	$(PRECMD)ar cr $(DIR_BUILD)/libs/static/libtagion$(*).a ${foreach OBJ, $(OBJS), $(DIR_BUILD)/libs/o/$(OBJ).o}
	${call log.kvp, Archived, $(@D)/libtagion$(*).a}

$(DIR_BUILD)/libs/o/%.o: $(DIR_BUILD)/libs/o/.touch
	${eval COMPILE := $(PRECMD)}
	${eval COMPILE += $(DC)}
	${eval COMPILE += $(DCFLAGS)}
	${eval COMPILE += -c}
	${eval COMPILE += -of$(DIR_BUILD)/libs/o/$(*).o}
	${eval COMPILE += $(INCFLAGS)}
	${eval COMPILE += ${call find.files, $(DIR_TUB_ROOT)/src/libs/$(*), *.d}}
	${eval COMPILE += $(LDCFLAGS)}
	$(COMPILE)
	${call log.kvp, Compiled, $(DIR_BUILD)/libs/o/$(*).o}

# 
# Clean build directory
# 
clean:
	${call log.lin, cleaning ./builds}
	@rm -rf $(DIR_BUILD)/*

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