ADRDOX:=doc2

env-docs:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, ADRDOX, $(ADRDOX))

.PHONY: env-doc

env: env-doc

clean-docs:
	$(PRECMD) rm -rv $(BUILDDOC)
	@echo cleaning docs

.PHONY: clean-doc

clean: clean-doc

help-docs:
	$(PRECMD)
	${call log.header, $@ :: help}
	${cal llog.help, "make docs", "Create the docs with addrdox"}

.PHONY: help-doc

help: help-doc

docs:
	@echo making docs
	$(PRECMD) doc2 -i --skeleton ${DTUB}/docs_template/skeleton.html -o $(BUILDDOC) $(DSRC)
