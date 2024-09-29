
.SUFFIXES:
.ONESHELL:

PREBUILD::=$(shell git submodule update)

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
export REPOROOT ::= $(dir $(mkfile_path))
SCRIPT:=$(REPOROOT)/tub

include $(REPOROOT)/tub/main.mk
