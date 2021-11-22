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
