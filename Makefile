
.SUFFIXES:
.ONESHELL:

# When building binaries in parrallell it crashes
# Presumable because the compilers can not read all files at the same time
.NOTPARALLEL: bins

export REPOROOT:=${shell git rev-parse --show-toplevel}
SCRIPT:=$(REPOROOT)/tub
include $(REPOROOT)/tub/main.mk

update_modules:
	git submodule update

.PHONY: update_modules

%: update_modules revision
