
LDC_TAR_NAME=ldc2-1.29.0-beta1-$(GETHOSTOS)-$(GETARHC).tar.xz
LDC_URL=https://github.com/ldc-developers/ldc/releases/download/v1.29.0-beta1/$(LDC_TAR)
LDC_TAR=$(TOOLS)/$(LDC_TAR_NAME)
TOOLS_LDC_BIN=$(TOOLS)/ldc/bin
#https://github.com/ldc-developers/ldc/releases/download/v1.29.0-beta1/ldc2-1.29.0-beta1-linux-x86_64.tar.xz

$(LDC_TAR): $(TOOLS)/.way
	$(PRECMD)
	$(MKDIR) $(TOOLS)
	$(TOUCH) $@
	$(CD) $(TOOLS); wget $(LDC_TAR)

$(TOOLS_LDC_BIN): $(LDC_TAR)
	$(PRECMD)
	tar -xJvf $@

#$(TOOLS)/$(LDC_T
