${eval ${call debug.open, MAKE COMPILE - $(MAKECMDGOALS)}}

INCLFLAGS := ${addprefix -I$(DIR_ROOT)/,${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}}

${eval ${call debug.lines, INCLFLAGS: $(INCLFLAGS)}}

tagion%: $(DIR_BUILD)/bins/tagion%
	@

libtagion%: $(DIR_BUILD_LIBS_STATIC)/libtagion%.a
	@

# 
# Targets
# 
$(DIR_BUILD_LIBS_STATIC)/libtagion%.a: $(DIR_BUILD_LIBS_STATIC)/.way $(DIR_BUILD_O)/libtagion%.o
	${call log.line, archive - $(@)}

$(DIR_BUILD_O)/libtagion%.o: $(DIR_BUILD_O)/.way
	${call log.line, $(*) includes}
	${call log.lines, $(INCLFLAGS)}


${eval ${call debug.close, MAKE COMPILE - $(MAKECMDGOALS)}}