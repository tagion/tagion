
DART_API_SERVICE=$(INTEGRATION)/vibed2-rest-api
DART_API_BUILD=$(DBUILD)/integration
DART_API_INSTALL_DIR=$(HOME)/.local/share/dart_api


dartapi: libtagion
	$(PRECMD)
	mkdir -p $(DART_API_BUILD)
	dub build --root=$(DART_API_SERVICE) --compiler=$(DC) --force 
	cp $(DART_API_SERVICE)/dart_api.service $(DART_API_BUILD)
	cp -r $(DART_API_SERVICE)/public $(DART_API_BUILD)
	cp $(DART_API_SERVICE)/install.sh $(DART_API_BUILD)

clean-dartapi:
	$(PRECMD)
	$(RM) -r $(DART_API_BUILD)
	@echo cleaning dartapi


.PHONY: clean-dartapi	

clean: clean-dartapi

help-dartapi:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make dartapi", "Build the dartapi"}
	${call log.help, "make clean-dartapi", "Removes the binary"}

.PHONY: help-dartapi
	