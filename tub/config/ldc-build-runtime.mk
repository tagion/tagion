
LDC_NAME=ldc2-1.29.0-beta1-$(GETHOSTOS)-$(GETARCH)
LDC_TAR_NAME=$(LDC_NAME).tar.xz
LDC_URL=https://github.com/ldc-developers/ldc/releases/download/v1.29.0-beta1/$(LDC_TAR_NAME)
LDC_TAR=$(TOOLS)/$(LDC_TAR_NAME)
TOOLS_LDC_BIN=$(TOOLS)/$(LDC_NAME)/bin
#https://github.com/ldc-developers/ldc/releases/download/v1.29.0-beta1/ldc2-1.29.0-beta1-linux-x86_64.tar.xz

$(LDC_TAR): $(TOOLS)/.way
	$(PRECMD)
	echo $(LDC_TAR)
	$(CD) $(TOOLS); wget $(LDC_URL)
	$(TOUCH) $@

$(TOOLS_LDC_BIN): $(LDC_TAR)
	$(PRECMD)
	$(CD) $(TOOLS); tar -xJvf $<
	$(TOUCH) $@

ldc-bin: $(TOOLS_LDC_BIN)
	@

ldc-tar: $(LDC_TAR)

.PHONY: ldc-tar

env-build-runtime:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, LDC_TAR_NAME, $(LDC_TAR_NAME)}
	${call log.kvp, LDC_NAME, $(LDC_NAME)}
	${call log.kvp, LDC_TAR, $(LDC_TAR)}
	${call log.kvp, LDC_URL, $(LDC_URL)}
	${call log.kvp, TOOLS_LCD_BIN, $(TOOLS_LDC_BIN)}
	${call log.close}

#$(TOOLS)/$(LDC_T
