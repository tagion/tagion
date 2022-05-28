
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
install: $(INSTALLEDTOOL)

#echo $(TOOL) $(INSTALL)
#	$(CP) $(DBIN)/tagion $(INSTALL)
#	$(LN)


$(INSTALLEDTOOL): ONETOOL=1
$(INSTALLEDTOOL): target-tagion
$(INSTALLEDTOOL): $(TOOL)
$(INSTALLEDTOOL): $(ALL_LINKS)
	$(PRECMD)
	$(CP) $(TOOL) $(INSTALLEDTOOL)

$(INSTALL)/%: $(TOOL)
	$(RRECMD)
	$(RM) $@
	$(LN) $< $@
