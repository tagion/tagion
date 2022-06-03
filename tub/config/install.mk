
TOOL=$(DBIN)/tagion
INSTALLEDTOOL=$(INSTALL)/tagion

TOOLLINKS+=tagionboot
TOOLLINKS+=tagionwallet
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
