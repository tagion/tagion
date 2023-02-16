DDFLAGS+=-Dd=$(BUILDDOC)
DDFLAGS+=-op -o-
DDFLAGS+=$(DVERSION)=OLD_TRANSACTION 
DDFLAGS+=-J=$(DBUILD) 
# We need the relative path since dmd will output the generated html in that relative directory
DDFILES+=${shell realpath --relative-to $(REPOROOT) $(DSRCALL)}
DDTEMPLATE+=$(DTUB)/docs_template/

env-ddoc:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, DDFLAGS, $(DDFLAGS))
	# $(call log.kvp, DDFILES, $(DDFILES))
	$(call log.kvp, DDTEMPLATE, $(DDTEMPLATE))

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
	${cal log.help, "make servedocs", "Run the md doc server and ddoc server"}

.PHONY: help-ddoc

help: help-ddoc

ddoc: $(DSRCALL)
	$(PRECMD)
	$(DC) $(DDFLAGS) $(DDFILES) ${addprefix -I,$(DINC)} $(DDTEMPLATE)/theme.ddoc
	$(CP) $(DDTEMPLATE)/style.css $(BUILDDOC)/

.PHONY: ddoc

servedocs:
	$(PRECMD)
	echo "Serving docs"
	(trap 'kill 0' SIGINT; docsify serve & $(CD) $(BUILDDOC) && python -m http.server 3001)
