ADRDOX:=dub run adrdox --

env-ddoc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, ADRDOX, $(ADRDOX))

.PHONY: env-ddoc

env: env-ddoc

clean-ddoc:
	$(PRECMD) rm -rv $(BUILDDOC)
	@echo cleaning docs

.PHONY: clean-ddoc

clean: clean-ddoc

help-ddoc:
	$(PRECMD)
	${call log.header, $@ :: help}
	${cal llog.help, "make docs", "Create the docs with addrdox"}

.PHONY: help-ddoc

help: help-ddoc

ddoc:
	@echo making docs
	$(PRECMD) $(ADRDOX) -i --skeleton $(DTUB)/docs_template/skeleton.html -o $(BUILDDOC) $(DSRC)

.PHONY: ddoc

