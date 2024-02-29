ADRDOX:=dub run adrdox --

env-doc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, ADRDOX, $(ADRDOX))

.PHONY: env-doc

env: env-doc

clean-ddoc:
	$(PRECMD)
	$(RM) -r $(BUILDDOC)
	@echo cleaning docs

.PHONY: clean-ddoc

clean: clean-ddoc

clean-doc:
	$(PRECMD)
	$(RM) -r $(BUILDDOCUSAURUS)
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
	$(ADRDOX) --skeleton $(DTUB)/docs_template/skeleton.html -o $(BUILDDOC) $(DSRC)/lib-*/tagion $(DSRC)/bin-*/tagion $(BDD)/tagion

.PHONY: ddoc

doc: ddoc $(BUILDDOCUSAURUS)/.way
	$(PRECMD)
	echo "making docusaurus"
	npm run build --prefix $(DOCUSAURUS)
	mkdir $(BUILDDOCUSAURUS)/ddoc
	$(CP) ${shell find $(BUILDDOC) -type f ! -name 'index.html'} $(BUILDDOCUSAURUS)/ddoc
.PHONY: doc

servedocs:
	$(PRECMD)
	echo "Serving docs"
	(trap 'kill 0' SIGINT; npm run serve --prefix $(DOCUSAURUS))


