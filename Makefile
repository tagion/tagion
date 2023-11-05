
.SUFFIXES:
.ONESHELL:

# When building binaries in parrallell it crashes
# Presumable because the compilers can not read all files at the same time
.NOTPARALLEL: bins

PREBUILD:=$(shell git submodule update)

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
export REPOROOT := $(dir $(mkfile_path))
SCRIPT:=$(REPOROOT)/tub

include $(REPOROOT)/tub/main.mk
