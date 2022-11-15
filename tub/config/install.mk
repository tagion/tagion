
TOOL=$(DBIN)/tagion
INSTALLEDTOOL=$(INSTALL)/tagion

TOOLLINKS+=tagionboot
TOOLLINKS+=tagionwallet
TOOLLINKS+=evilwallet
TOOLLINKS+=tagionwave
TOOLLINKS+=dartutil
TOOLLINKS+=hibonutil

TOOLLINKS+=boot
TOOLLINKS+=wallet
TOOLLINKS+=wave


ALL_LINKS=${addprefix $(INSTALL)/,$(TOOLLINKS)}



install: ONETOOL=1
install: target-tagion
install: $(INSTALLEDTOOL)


$(INSTALLEDTOOL): ONETOOL=1
$(INSTALLEDTOOL): $(TOOL)
$(INSTALLEDTOOL): $(ALL_LINKS)
	$(PRECMD)
	$(CP) $(TOOL) $(INSTALLEDTOOL)

$(INSTALL)/%: $(TOOL)
	$(RRECMD)
	$(RM) $@
	$(LN) $< $@

env-install:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, INSTALL, $(INSTALL)}
	${call log.kvp, INSTALLEDTOOL, $(INSTALLEDTOOL)}
	${call log.env, TOOLLINKS, $(TOOLLINKS)}
	${call log.env, ALL_LINKS, $(ALL_LINKS)}
	${call log.close}

.PHONY: env-install

env: env-install

uninstall: 
	$(PRECMD)
	$(RM) $(ALL_LINKS)
	$(RM) $(TOOL)

help-install:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make install", "Install the tagion tools"}
	${call log.help, "make uninstall", "Uninstall the tagion tools"}
	${call log.help, "make env-install", "List the install environment"}
	${call log.close}



