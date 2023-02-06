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
	${cal log.help, "make ddoc", "Create the docs with addrdox"}

.PHONY: help-ddoc

help: help-ddoc

ddoc:
	$(PRECMD) 
	echo "making ddoc"
	$(ADRDOX) -i --skeleton $(DTUB)/docs_template/skeleton.html -o $(BUILDDOC) $(DSRC)

.PHONY: ddoc

servedocs:
	$(PRECMD)
	echo "Serving docs"
	docsify serve -p 3000 &
	$(CD) $(BUILDDOC) &&
	python -m http.server 3001 &
