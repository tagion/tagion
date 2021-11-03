# Filter out other modeules and include O files when lonking from all moduels (based on deps.mk)

${eval ${call debug.open, MAKE COMPILE - $(MAKECMDGOALS)}}

INCLFLAGS := ${addprefix -I$(DIR_ROOT)/,${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}}

ifndef DEPS_UNRESOLVED
tagion%: $(DIR_BUILD)/bins/tagion%
	@

libtagion%: $(DIR_BUILD_LIBS_STATIC)/libtagion%.a
	@

test-libtagion%: $(DIR_BUILD_BINS)/test-libtagion%
	@$(DIR_BUILD_BINS)/test-libtagion$(*)

# 
# Targets
# 
$(DIR_BUILD_O)/libtagion%.o: $(DIR_BUILD_O)/.way 
	${call redefine.vars.o, lib}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCLFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

$(DIR_BUILD_O)/test-libtagion%.o: $(DIR_BUILD_O)/.way 
	${call redefine.vars.o.test, lib}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCLFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}


$(DIR_BUILD_LIBS_STATIC)/libtagion%.a: $(DIR_BUILD_LIBS_STATIC)/.way
	${call redefine.vars.a}
	${if $(LOGS), ${call details.archive}}
	$(PRECMD)ar cr $(@) $(_ARCHIVES)
	${call log.kvp, Archived, $(@)}

$(DIR_BUILD_BINS)/test-libtagion%: $(DIR_BUILD_BINS)/.way
	${call redefine.vars.test}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}
endif

define details.compile
${call log.header, Compile $(@F)}
${call log.kvp, DC, $(DC)}
${call log.kvp, DCFLAGS, $(_DCFLAGS)}
${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}
${if $(_INCLFLAGS),${call log.kvp, INCLFLAGS}}
${if $(_INCLFLAGS),${call log.lines, $(_INCLFLAGS)}}
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

define redefine.vars.o.common
${eval _DCFLAGS := $(DCFLAGS)}
${eval _LDCFLAGS := $(LDCFLAGS)}
${eval _INCLFLAGS := $(INCLFLAGS)}
${eval _INFILES := ${filter $(DIR_SRC)/${strip $1}-$(*)/%.d,$(^)}}
${eval _INFILES += ${filter $(DIR_SRC)/${strip $1}-$(*)/%.di,$(^)}}
${eval _INFILES += ${filter $(DIR_BUILD_WRAPS)/%.d,$(^)}}
${eval _INFILES += ${filter $(DIR_BUILD_WRAPS)/%.di,$(^)}}
endef

define redefine.vars.o
${call redefine.vars.o.common, $1}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of $(@)}
endef

define redefine.vars.o.test
${call redefine.vars.o.common, $1}
${eval _DCFLAGS += -unittest}
${eval _DCFLAGS += -g}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of$(@)}
endef

define redefine.vars.test
${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -main}
${eval _DCFLAGS += -of$(@)}
${eval _LDCFLAGS := $(LDCFLAGS)}
${eval _INCLFLAGS := }
${eval _INFILES := ${filter $(DIR_BUILD_O)/%.o,$(^)}}
endef

define redefine.vars.a
${eval _ARCHIVES := ${filter $(DIR_BUILD_O)/%.o,$(^)}}
endef

define find.files
${shell find ${strip $1} -name '${strip $2}'}
endef


${eval ${call debug.close, MAKE COMPILE - $(MAKECMDGOALS)}}