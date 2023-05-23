#
# This makefile call the tub/main.mk
# and controlles the prebuild
#
.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

TUB_COMMIT=xxx
TUB_BRANCH=yy
REPOROOT?=$(PWD)
#export REPOROOT:=${shell git rev-parse --show-toplevel}
MAIN_MK:=$(REPOROOT)/tub/main.mk

include $(MAIN_MK)

