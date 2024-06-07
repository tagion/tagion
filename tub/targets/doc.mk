ADRDOX:=dub run adrdox --

env-doc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, ADRDOX, $(ADRDOX))

.PHONY: env-doc

env: env-doc

clean-ddoc:
	$(PRECMD)
	$(RM) -rf $(BUILDDOC)
	@echo cleaning docs

.PHONY: clean-ddoc

clean: clean-ddoc

clean-doc:
	$(PRECMD)
	$(RM) -rf $(BUILDDOCUSAURUS)
	@echo cleaning docusaurus

.PHONY: clean-doc
clean: clean-doc

help-doc:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make ddoc", "Create the docs with addrdox"}
	${call log.help, "make doc", "Create ddoc and build docs server"}
	${call log.help, "make servedocs", "Run the documentation server"}

.PHONY: help-doc

help: help-doc

ddoc: $(BUILDDOC)/.way
	$(PRECMD) 
	echo "making ddoc"
	$(ADRDOX) --skeleton $(DTUB)/docs_template/skeleton.html -o $(BUILDDOC) $(DSRC)/lib-*/tagion $(DSRC)/lib-nngd/nngd $(DSRC)/bin-*/tagion $(BDD)/tagion

.PHONY: ddoc

doc: ddoc $(BUILDDOCUSAURUS)/.way
	$(PRECMD)
	echo "making docusaurus"
	npm run build --prefix $(DOCUSAURUS)
	$(CP) -r $(BUILDDOC) $(BUILDDOCUSAURUS)
	$(RM) $(BUILDDOCUSAURUS)/ddoc/index.html
	echo run 'make servedocs' to start the documentation server

doc-sitemap: 
	$(PRECMD)
	echo "making sitemap"
	python3 $(DOCUSAURUS)/create_sitemap.py $(BUILDDOCUSAURUS)/sitemap.xml $(BUILDDOCUSAURUS)/ddoc

.PHONY: doc

servedocs:
	$(PRECMD)
	echo "Serving docs"
	npm run serve --prefix $(DOCUSAURUS)
