DIR_MAKEFILE := ${realpath .}
DIR_MAKER := $(DIR_MAKEFILE)

ifneq ($(shell test -e env.mk && echo -n yes),yes)
DIR_MAKER := $(DIR_MAKEFILE)/maker
endif

include $(DIR_MAKER)/utils.mk
include $(DIR_MAKER)/log.mk
include $(DIR_MAKER)/help.mk
include $(DIR_MAKER)/info.mk
include $(DIR_MAKER)/env.mk
include $(DIR_MAKER)/meta.mk
include $(DIR_MAKER)/compile.mk

help: $(HELP)
info: $(INFO)
.PHONY: help info

