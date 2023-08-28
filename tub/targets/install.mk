
TOOL=$(DBIN)/tagion
INSTALLEDTOOL=$(INSTALL)/tagion
INSTALLEDCOLLIDER=$(INSTALL)/collider


install: ONETOOL=1
install: target-tagion
install: $(INSTALLEDTOOL)
install: collider


$(INSTALLEDTOOL): ONETOOL=1
$(INSTALLEDTOOL): $(TOOL)
	$(PRECMD)
	$(CP) $(TOOL) $(INSTALLEDTOOL)
	$(INSTALLEDTOOL) -f
	$(CP) $(COLLIDER) $(INSTALLEDCOLLIDER)
	$(INSTALLEDCOLLIDER) -f

env-install:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, INSTALL, $(INSTALL)}
	${call log.kvp, INSTALLEDTOOL, $(INSTALLEDTOOL)}
	${call log.kvp, INSTALLEDCOLLIDER, $(INSTALLEDCOLLIDER)}
	${call log.close}

.PHONY: env-install

env: env-install

uninstall: 
	$(PRECMD)
	$(RM) $(INSTALLEDCOLLIDER)
	$(RM) $(INSTALLEDTOOL)

help-install:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make install", "Install the tagion tools"}
	${call log.help, "make uninstall", "Uninstall the tagion tools"}
	${call log.help, "make env-install", "List the install environment"}
	${call log.close}



