# OS & ARCH
OS ?= $(GETHOSTOS)

ifndef ARCH
ifeq ($(OS),"windows")
ifeq ($(PROCESSOR_ARCHITECTURE), x86)
ARCH = x86
else
ARCH = x86_64
endif
else
ARCH = $(GETARCH)
endif
endif


# This is the host name
HOST:=${call join-with,-,$(GETHOSTOS) $(GETARCH)}

ifneq ($(PLATFORM),$(HOST_PLATFORM))
CROSS_ENABLED?=1
endif

# Version 3.81 is installed by default on macOS, but doesn't support ONESHELL
OLDVERSION := 3.81
MAKEVERSION := ${shell make -v}
MAKEVERSION_MATCH := ${findstring $(OLDVERSION),$(MAKEVERSION)}
ifeq ($(MAKEVERSION_MATCH),$(OLDVERSION))
${info ERROR}
${info Your Make version is tool old ($(MAKEVERSION_MATCH))}
${info Install newer version: http://ftp.gnu.org/gnu/make/}
${error Unsupported GNU Make version}
endif

# ifneq ($(PLATFORM),$(HOST_PLATFORM))
# CROSS_ENABLE?=yes
# endif

env-host:
	$(PRECMD)
	$(call log.header, $@ :: host)
	$(call log.kvp, OS, $(OS))
	$(call log.kvp, ARCH, $(ARCH))
	${call log.kvp, HOST, $(HOST)}
	${call log.kvp, HOST_PLATFORM, $(HOST_PLATFORM)}
	${call log.kvp, PLATFORM, $(PLATFORM)}
	${call log.kvp, CROSS_ENABLED, $(CROSS_ENABLED)}
	$(call log.close)

env: env-host

#PLATFORM1?=$(call join-with,:,)
