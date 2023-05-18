dartapi: libtagion
	$(PRECMD)
	mkdir -p $(DART_API_BUILD)
	dub build --root=$(DART_API_SERVICE) --compiler=$(DC)

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

.PHONY: help-dartapi
	