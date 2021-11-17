lib%.o: $(DTMP)/lib%.o
	@

lib%.a: $(DBIN)/lib%.a
	@

$(DTMP)/lib%.o: $(DTMP)/lib%.way
	${call redefine.vars.o, lib}
	${eval $*INFILES := ${filter $(DSRC)/lib-$*/%.d,$^}}
	${eval $*INFILES += ${filter $(DSRC)/lib-$*/%.di,$^}}
	${call details.compile}
	$(PRECMD)$(DC) $(DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $(@)}

$(DBIN)/lib%.a: $(DBIN)/lib%.way
	${call redefine.vars.lib}
	${if $(LOGS), ${call details.archive}}
	$(PRECMD)ldc2 ${if $(CROSS_ENABLED),-mtriple=$(MTRIPLE)} -lib $(_INFILES) -of$(@)
	${call log.kvp, Archived, $(@)}

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
