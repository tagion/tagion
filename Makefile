
.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

export REPOROOT:=${shell git rev-parse --show-toplevel}
SCRIPT:=$(REPOROOT)/tub
include $(REPOROOT)/tub/main.mk

update_modules:
	git submodule update

.PHONY: update_modules

%: update_modules
