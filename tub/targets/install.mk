# Install script for gnu linux
MKDIR?=mkdir -p
CP?=cp -a

# REDEFINE VARS FOR STANDALONE USE
ifdef PLATFORM
TOOL_TARGET=tagion
else 
TOOL_TARGET=${TOOL}
endif
INSTALL?=${HOME}/.local/bin
GETHOSTOS?=${shell uname | tr A-Z a-z}
GETARCH?=${shell uname -m}
PLATFORM?=$(GETARCH)-$(GETHOSTOS)
DBIN?=build/${PLATFORM}/bin
XDG_DATA_HOME?=$(HOME)/.local/share
XDG_CONFIG_HOME?=$(HOME)/.config
TAGION_DATA:=$(XDG_DATA_HOME)/tagion/wave


install: install-bin install-scripts install-services


TOOL=$(DBIN)/tagion
INSTALLEDTOOL=$(INSTALL)/tagion
INSTALLED_FILES+=$(INSTALLEDTOOL)

# Install tagion
install-bin: $(INSTALLEDTOOL)
$(INSTALLEDTOOL): $(TOOL_TARGET)
	$(PRECMD)
	$(CP) $(TOOL) $(INSTALLEDTOOL)
	$(INSTALLEDTOOL) -f


INSTALLED_RUN_NETWORK_SH:=$(TAGION_DATA)/run_network.sh
INSTALLED_FILES+=$(INSTALLED_RUN_NETWORK_SH)

install-scripts: $(INSTALLED_RUN_NETWORK_SH)
$(INSTALLED_RUN_NETWORK_SH): scripts/run_network.sh
	$(MKDIR) $(TAGION_DATA)
	$(CP) $< $@


NEUEWELLE_SERVICE:=$(XDG_CONFIG_HOME)/systemd/user/neuewelle.service
INSTALLED_FILES+=$(NEUEWELLE_SERVICE)
TAGIONSHELL_SERVICE:=$(XDG_CONFIG_HOME)/systemd/user/tagionshell.service
INSTALLED_FILES+=$(TAGIONSHELL_SERVICE)

install-services: $(NEUEWELLE_SERVICE) $(TAGIONSHELL_SERVICE)
$(XDG_CONFIG_HOME)/systemd/user/%: etc/%
	$(MKDIR) $(XDG_CONFIG_HOME)/systemd/user/
	$(CP) $< $@


# Install extra development tools
INSTALLEDCOLLIDER=$(INSTALL)/collider
INSTALLED_FILES+=$(INSTALLEDCOLLIDER)
install-dev: install $(INSTALLEDCOLLIDER)
$(INSTALLEDCOLLIDER): collider
	$(PRECMD)
	$(CP) $(COLLIDER) $(INSTALLEDCOLLIDER)
	$(INSTALLEDCOLLIDER) -f

# Auxiliary scripts for operations testing
OPS_SERVICE:=$(XDG_CONFIG_HOME)/systemd/user/tagion-ops-mngr.service
INSTALLED_FILES+=$(OPS_SERVICE)
OPS_TIMER:=$(XDG_CONFIG_HOME)/systemd/user/tagion-ops-mngr.timer
INSTALLED_FILES+=$(OPS_TIMER)
install-ops: install $(OPS_SERVICE) $(OPS_TIMER)

env-install:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, INSTALL, $(INSTALL)}
	${call log.env, INSTALLED_FILES, $(INSTALLED_FILES)}
	${call log.close}

.PHONY: env-install

env: env-install

uninstall: 
	$(PRECMD)
	$(RM) $(INSTALLEDCOLLIDER)
	$(RM) $(INSTALLED_FILES)

help-install:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make install", "Install the tagion tools"}
	${call log.help, "make uninstall", "Uninstall the tagion tools"}
	${call log.help, "make env-install", "List the install environment"}
	${call log.close}
