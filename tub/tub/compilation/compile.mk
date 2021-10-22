${eval ${call debug.open, MAKE COMPILE - $(MAKECMDGOALS)}}

INCLFLAGS := ${addprefix -I$(DIR_ROOT)/,${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}}

# ${eval ${call debug.lines, INCLFLAGS: $(INCLFLAGS)}}

ifndef DEPS_UNRESOLVED
tagion%: $(DIR_BUILD)/bins/tagion%
	@

libtagion%: $(DIR_BUILD_LIBS_STATIC)/libtagion%.a
	@
endif

# 
# Targets
# 
$(DIR_BUILD_LIBS_STATIC)/libtagion%.a: $(DIR_BUILD_LIBS_STATIC)/.way $(DIR_BUILD_O)/libtagion%.o
	${call log.line, archive - $(@)}

$(DIR_BUILD_O)/libtagion%.o: $(DIR_BUILD_O)/.way $(DIR_SRC)/lib-%/$(FILENAME_SOURCE_MK)
	@echo o target

${eval ${call debug.close, MAKE COMPILE - $(MAKECMDGOALS)}}