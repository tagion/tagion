
DART_API_SERVICE=$(INTEGRATION)/vibed-rest-api
DART_API_TWO_SERVICE=$(INTEGRATION)/vibed2-rest-api
DART_API_BUILD=$(DBUILD)/integration
DART_API_INSTALL_DIR=$(HOME)/.local/share/dart_api


dartapi: libtagion
	$(PRECMD)
	mkdir -p $(DART_API_BUILD)
	dub build --root=$(DART_API_SERVICE) --compiler=$(DC)

dartsecondapi: libtagion
	$(PRECMD)
	mkdir -p $(DART_API_BUILD)
	dub build --root=$(DART_API_TWO_SERVICE) --compiler=$(DC)
	cp $(DART_API_TWO_SERVICE)/dart_api.service $(DART_API_BUILD)
	cp $(DART_API_TWO_SERVICE)/install.sh $(DART_API_BUILD)

install-dartapi: dartapi
	mkdir -p $(DART_API_INSTALL_DIR)
	mkdir -p $(HOME)/.config/systemd/user
	cp $(DART_API_BUILD)/vibed-project $(DART_API_INSTALL_DIR)
	cp $(DART_API_SERVICE)/dart_api.service $(HOME)/.config/systemd/user/
	systemctl --user daemon-reload
	@echo "restart the service with: systemctl restart --user dart_api"


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
	${call log.help, "make install-dartapi", "Installs the dartapi systemctl"}
	${call log.help, "make clean-dartapi", "Removes the binary"}

.PHONY: help-dartapi
	