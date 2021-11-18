lib%.test.o: $(DTMP)/lib%.test.o
	@

lib%.test: $(DBIN)/lib%.test
	$(DBIN)/lib$*.test

$(DTMP)/lib%.test.o: $(DTMP)/lib%.way
	${eval $*DCFLAGS := -c -unittest -g -of$@}
	${eval $*INFILES := ${filter $(DSRC)/lib-$*/%.d,$^}}
	${eval $*INFILES += ${filter $(DSRC)/lib-$*/%.di,$^}}
	${if $(LOGS),${call details.compile}}
	$(PRECMD)$(DC) $(DCFLAGS) $($*DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

$(DBIN)/lib%.test: $(DBIN)/lib%.test.way
	${eval $*DCFLAGS := -main -of$@}
	${eval $*INFILES := ${filter %.o,$^}}
	${if $(LOGS),${call details.compile}}
	$(PRECMD)$(DC) $(DCFLAGS) $($*DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

lib%.o: $(DTMP)/lib%.o
	@

lib%: $(DBIN)/lib%.a
	@

lib%.a: $(DBIN)/lib%.a
	@

$(DTMP)/lib%.o: DCFLAGS += -c
$(DTMP)/lib%.o: DCFLAGS += -of$@
$(DTMP)/lib%.o: $(DTMP)/lib%.way
	${eval $*INFILES := ${filter $(DSRC)/lib-$*/%.d,$^}}
	${eval $*INFILES += ${filter $(DSRC)/lib-$*/%.di,$^}}
	${if $(LOGS),${call details.compile}}
	$(PRECMD)$(DC) $(DCFLAGS) $($*INFILES) $(INFILES) $(INCLFLAGS) $(LDCFLAGS)
	${call log.kvp, Compiled, $@}

$(DBIN)/lib%.a: $(DBIN)/lib%.way
	${eval $*INFILES := ${filter %.o,$^}}
	${if $(LOGS),${call details.archive}}
	$(PRECMD)ldc2 ${if $(CROSS_ENABLED),-mtriple=$(MTRIPLE)} -lib $(INFILES) $($*INFILES) -of$@
	${call log.kvp, Archived, $@}

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
