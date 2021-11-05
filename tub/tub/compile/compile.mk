${eval ${call debug.open, MAKE COMPILE - $(MAKECMDGOALS)}}

ifndef DEPS_UNRESOLVED
# Binaries
tagion%: ${call bin,%}
	@

${call bin.o,%}: ${call bin.o}.way
	${call redefine.vars.o, bin}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCLFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

${call bin,%}: ${call bin}.way ${call bin.o,%} ${foreach _,${filter lib-%,$(DEPS)},${call lib.o,${subst lib-,,$(_)}}}
	${call redefine.vars.bin}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_LINKFILES) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

# Libraries
ifdef TEST
${eval ${call debug, Compiling tests...}}

libtagion%: ${call lib,%}
	${call log.header, Running tests lib-$(*) (Make level $(MAKELEVEL))}
	@${call lib,$*}
	${call log.close}

${call lib.o,%}: ${call lib.o}.way 
	${call redefine.vars.o.test, lib}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCLFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

${call lib,%}: ${call lib}.way ${call lib.o,%} ${foreach _,${filter lib-%,$(DEPS)},${call lib.o,${subst lib-,,$(_)}}}
	${call redefine.vars.lib}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_LINKFILES) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}
else
${eval ${call debug, Compiling library...}}

libtagion%: ${call lib,%}
	@

${call lib.o,%}: ${call lib.o}.way
	${call redefine.vars.o, lib}
	${if $(LOGS), ${call details.compile}}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCLFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

${call lib,%}: ${call lib}.way ${call lib.o,%} ${foreach _,${filter lib-%,$(DEPS)},${call lib.o,${subst lib-,,$(_)}}}
	${call redefine.vars.lib}
	${if $(LOGS), ${call details.archive}}
	$(PRECMD)ar cr $(@) $(_INFILES)
	${call log.kvp, Archived, $(@)}
endif
endif

# Vars definitions
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
${eval _DCFLAGS += -of$(@)}
endef

define redefine.vars.o.test
${call redefine.vars.o.common, $1}
${eval _DCFLAGS += -unittest}
${eval _DCFLAGS += -g}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of$(@)}
endef

define redefine.vars.bin
${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -of$(@)}
${eval _LDCFLAGS := $(LDCFLAGS)}
${eval _INCLFLAGS := }
${eval _INFILES := ${filter $(DIR_BUILD_O)/%.o,$(^)}}
${eval _INFILES += $(INFILES)}
endef

ifdef TEST
define redefine.vars.lib
${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -main}
${eval _DCFLAGS += -of$(@)}
${eval _LDCFLAGS := $(LDCFLAGS)}
${eval _LINKFILES := ${addprefix -L,$(LINKFILES)}}
${eval _INCLFLAGS := }
${eval _INFILES := ${filter $(DIR_BUILD_O)/%.o,$(^)}}
${eval _INFILES += $(INFILES)}
endef
else
define redefine.vars.lib
${eval _INFILES := ${filter $(DIR_BUILD_O)/%.o,$(^)}}
${eval _INFILES += $(INFILES)}
endef
endif

# Logs
define details.compile
${call log.header, Compile $(@F)}
${call log.kvp, DC, $(DC)}
${call log.kvp, DCFLAGS, $(_DCFLAGS)}
${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}
${if $(_INCLFLAGS),${call log.kvp, INCLFLAGS}}
${if $(_INCLFLAGS),${call log.lines, $(_INCLFLAGS)}}
${if $(_LINKFILES),${call log.kvp, LINKFILES}}
${if $(_LINKFILES),${call log.lines, $(_LINKFILES)}}
${call log.kvp, INFILES}
${call log.lines, $(_INFILES)}
${call log.close}
endef

define details.archive
${call log.header, Archive $(@F)}
${call log.kvp, INFLILES}
${call log.lines, $(_INFILES)}
${call log.close}
endef

${eval ${call debug.close, MAKE COMPILE - $(MAKECMDGOALS)}}

