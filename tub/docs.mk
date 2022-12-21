ADRDOX:=doc2

env-doc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, ADRDOX, $(ADRDOX))

clean-doc:
	$(PRECMD) rm -rv $(BUILDDOC)
	@echo cleaning docs

help-doc:
	$(PRECMD)
	${call log.header, $@ :: help}
	${cal llog.help, "make docs", "Create the docs with addrdox"}

doc:
	@echo making docs
	$(PRECMD) doc2 -i --skeleton ${DTUB}/docs_template/skeleton.html -o $(BUILDDOC) $(DSRC)
