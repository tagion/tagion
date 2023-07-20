ADRDOX:=dub run adrdox --

env-ddoc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, ADRDOX, $(ADRDOX))

.PHONY: env-ddoc

env: env-ddoc

clean-ddoc:
	$(PRECMD)
	$(RM) -r $(BUILDDOC)
	@echo cleaning docs

.PHONY: clean-ddoc

clean: clean-ddoc

help-ddoc:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make ddoc", "Create the docs with addrdox"}
	${call log.help, "make servedocs", "Run the md doc server and ddoc server"}

.PHONY: help-ddoc

help: help-ddoc

ddoc: $(BUILDDOC)/.way
	$(PRECMD) 
	echo "making ddoc"
	$(ADRDOX) --document-undocumented --skeleton $(DTUB)/docs_template/skeleton.html -o $(BUILDDOC) $(DSRC)/lib-*/tagion $(DSRC)/bin-*/tagion $(BDD)/tagion

.PHONY: ddoc

servedocs:
	$(PRECMD)
	echo "Serving docs"
	(trap 'kill 0' SIGINT; docsify serve & $(CD) $(BUILDDOC) && python3 -m http.server 3001)
