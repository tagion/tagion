${eval ${call debug.open, MAKE COMPILE - $(MAKECMDGOALS)}}

INCLFLAGS := ${addprefix -I$(DIR_ROOT)/,${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}}

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
	${call redefine.vars.a}
	${call details.archive}
	$(PRECMD)ar cr $(@) $(_ARCHIVES)
	${call log.kvp, Archived, $(@)}

$(DIR_BUILD_O)/libtagion%.o: $(DIR_BUILD_O)/.way 
	${call redefine.vars.o}
	${call details.compile}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INCLFLAGS) $(_INFILES) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

${eval ${call debug.close, MAKE COMPILE - $(MAKECMDGOALS)}}


define details.compile
${call log.header, Compile $(@F)}
${call log.kvp, DC, $(DC)}
${call log.kvp, DCFLAGS, $(_DCFLAGS)}
${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}
${call log.kvp, INCLFLAGS}
${call log.lines, $(_INCLFLAGS)}
${call log.kvp, INFILES}
${call log.lines, $(_INFILES)}
${call log.close}
endef

define details.archive
${call log.header, Archive $(@F)}
${call log.kvp, ARCHIVES}
${call log.lines, $(_ARCHIVES)}
${call log.close}
endef

define redefine.vars.o
${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of $(@)}
${eval _LDCFLAGS := $(LDCFLAGS)}
${eval _INCLFLAGS := $(INCLFLAGS)}
${eval _INFILES := ${filter $(DIR_SRC)/lib-%.d,$(^)}}
${eval _INFILES += ${filter $(DIR_SRC)/bin-%.d,$(^)}}
${eval _INFILES += ${filter $(DIR_SRC)/wrap-%.d,$(^)}}
${eval _INFILES += ${filter $(DIR_BUILD_WRAPS)/%.d,$(^)}}
${eval _INFILES += ${filter $(DIR_SRC)/lib-%.di,$(^)}}
${eval _INFILES += ${filter $(DIR_SRC)/bin-%.di,$(^)}}
${eval _INFILES += ${filter $(DIR_SRC)/wrap-%.di,$(^)}}
${eval _INFILES += ${filter $(DIR_BUILD_WRAPS)/%.di,$(^)}}
endef

define redefine.vars.a
${eval _ARCHIVES := ${filter $(DIR_BUILD_O)/%.o,$(^)}}
endef