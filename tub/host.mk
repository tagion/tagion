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

MAKE_ENV += env-host
env-host:
	$(call log.header, env :: host)
	$(call log.kvp, OS, $(OS))
	$(call log.kvp, ARCH, $(ARCH))
	$(call log.close)