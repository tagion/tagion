LOGS = 1

lib%.test.o: $(DTMP)/lib%.test.o
	@

lib%.test: $(DBIN)/lib%.test
	$(DBIN)/lib$*.test

$(DTMP)/lib%.test.o: $(DTMP)/lib%.way
	$(PRECMD)
	${eval $*DCFLAGS := -c -unittest -g -of$@}
	${eval $*INFILES := ${filter $(DSRC)/lib-$*/%.d,$^}}
	${eval $*INFILES += ${filter $(DSRC)/lib-$*/%.di,$^}}
	${if $(LOGS),${call details.compile}}
	$(DC) $(DCFLAGS) $($*DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

$(DBIN)/lib%.test: $(DBIN)/lib%.test.way
	$(PRECMD)
	${eval $*DCFLAGS := -main -of$@}
	${eval $*INFILES := ${filter %.o,$^}}
	${eval $*INFILES += ${filter %.a,$^}}
	${if $(LOGS),${call details.compile}}
	$(DC) $(DCFLAGS) $($*DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

lib%.o: $(DTMP)/lib%.o
	@

lib%: $(DBIN)/lib%.a
	@

lib%.a: $(DBIN)/lib%.a
	@

$(DTMP)/lib%.o: $(DTMP)/lib%.way
	$(PRECMD)
	${eval $*DCFLAGS := -c -of$@}
	${eval $*INFILES := ${filter $(DSRC)/lib-$*/%.d,$^}}
	${eval $*INFILES += ${filter $(DSRC)/lib-$*/%.di,$^}}
	${if $(LOGS),${call details.compile}}
	$(DC) ${if $(CROSS_ENABLED),-mtriple=$(MTRIPLE)} $(DCFLAGS) $($*DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

$(DBIN)/lib%.a: $(DBIN)/lib%.way
	$(PRECMD)
	${eval $*INFILES := ${filter %.o,$^}}
	${if $(LOGS),${call details.archive}}
	$(DC) ${if $(CROSS_ENABLED),-mtriple=$(MTRIPLE)} -lib $(INFILES) $($*INFILES) -of$@
	${call log.kvp, Archived, $@}

tagion%.o: $(DTMP)/tagion%.o
	@

tagion%: $(DBIN)/tagion%
	@

$(DTMP)/tagion%.o: $(DTMP)/%.way
	$(PRECMD)
	${eval $*DCFLAGS := -c -of$@}
	${eval $*INFILES := ${filter $(DSRC)/bin-$*/%.d,$^}}
	${eval $*INFILES += ${filter $(DSRC)/bin-$*/%.di,$^}}
	${if $(LOGS),${call details.compile}}
	$(DC) ${if $(CROSS_ENABLED),-mtriple=$(MTRIPLE)} $(DCFLAGS) $($*DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

$(DBIN)/tagion%: $(DBIN)/%.way
	$(PRECMD)
	${eval $*DCFLAGS := -of$@}
	${eval $*INFILES := ${filter $(DSRC)%.d,$^}}
	${eval $*INFILES += ${filter %.a,$^}}
	${if $(LOGS),${call details.compile}}
	$(DC) ${if $(CROSS_ENABLED),-mtriple=$(MTRIPLE)} $(DCFLAGS) $($*DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

# Logs
define details.compile
${call log.header, Compile $(@F)}
${call log.kvp, DC, $(DC)}
${call log.kvp, DCFLAGS, $(DCFLAGS) $($*DCFLAGS)}
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
${call log.lines, $($*INFILES)}
${call log.lines, $(INFILES)}
${call log.close}
endef
