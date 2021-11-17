${eval ${call debug.open, MAKE COMPILE - $(MAKECMDGOALS)}}

lib%.a: $(DBIN)/lib%.a
	@

$(DTMP)/lib%.o: $(DTMP)/lib%.way
	${call redefine.vars.o, lib}
	${eval $*INFILES := ${filter $(DIR_SRC)/lib-$*/%.d,$^}}
	${eval $*INFILES += ${filter $(DIR_SRC)/lib-$*/%.di,$^}}
	$(PRECMD)$(DC) $(DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

$(DBIN)/lib%.a: $(DBIN)/lib%.way
	${call redefine.vars.lib}
	${if $(LOGS), ${call details.archive}}
	$(PRECMD)ldc2 ${if $(MTRIPLE),-mtriple=$(MTRIPLE)} -lib $(_INFILES) -of$(@)
	${call log.kvp, Archived, $(@)}

# Vars definitions
define redefine.vars.o.common
${eval _DCFLAGS := $(DCFLAGS)}
${if $(CROSS_COMPILE), ${eval _DCFLAGS += -mtriple=$(MTRIPLE)}}
${eval _INFILES := ${filter $(DIR_SRC)/${strip $1}-$(*)/%.d,$^}}
${eval _INFILES += ${filter $(DIR_SRC)/${strip $1}-$(*)/%.di,$^}}
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
${if $(CROSS_COMPILE), ${eval _DCFLAGS += -mtriple=$(MTRIPLE)}}
${eval _DCFLAGS += -of$(@)}
${eval _LDCFLAGS := $(LDCFLAGS)}
${eval _INCLFLAGS := }
${eval _INFILES := ${filter $(DIR_BUILD_O)/%.o,$^}}
${eval _INFILES += $(INFILES)}
endef

ifdef TEST
define redefine.vars.lib
${eval _DCFLAGS := $(DCFLAGS)}
${if $(CROSS_COMPILE), ${eval _DCFLAGS += -mtriple=$(MTRIPLE)}}
${eval _DCFLAGS += -main}
${eval _DCFLAGS += -of$(@)}
${eval _LDCFLAGS := $(LDCFLAGS)}
${eval _LINKFILES := ${addprefix -L,$(LINKFILES)}}
${eval _INCLFLAGS := }
${eval _INFILES := ${filter $(DIR_BUILD_O)/%.o,$^}}
${eval _INFILES += $(INFILES)}
endef
else
define redefine.vars.lib
${eval _INFILES := ${filter $(DIR_BUILD_O)/%.o,$^}}
${eval _INFILES += $(INFILES)}
endef
endif

# Logs
define details.compile
${call log.header, Compile $(@F)}
${call log.kvp, DC, $(DC)}
${call log.kvp, DCFLAGS, $_DCFLAGS)}
${call log.kvp, LDCFLAGS, $(LDCFLAGS)}
${if $(INCLFLAGS),${call log.kvp, INCLFLAGS}}
${if $(INCLFLAGS),${call log.lines, $(INCLFLAGS)}}
${if $(LINKFILES),${call log.kvp, LINKFILES}}
${if $(LINKFILES),${call log.lines, $(LINKFILES)}}
${call log.kvp, INFILES}
${call log.lines, $($*INFILES)}
${call log.lines, $(INFILES)}
${call log.close}
endef

define details.archive
${call log.header, Archive $(@F)}
${call log.kvp, INFLILES}
${call log.lines, $(INFILES)}
${call log.close}
endef

${eval ${call debug.close, MAKE COMPILE - $(MAKECMDGOALS)}}

