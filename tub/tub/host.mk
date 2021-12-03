# OS & ARCH
OS ?= $(shell uname | tr A-Z a-z)

ifndef ARCH
ifeq ($(OS),"windows")
ifeq ($(PROCESSOR_ARCHITECTURE), x86)
ARCH = x86
else
ARCH = x86_64
endif
else
ARCH = $(shell uname -m)
endif
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

MAKE_ENV += env-host
env-host:
	$(call log.header, env :: host)
	$(call log.kvp, OS, $(OS))
	$(call log.kvp, ARCH, $(ARCH))
	$(call log.close)