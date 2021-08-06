# Choosing anchor directory between root of the lab and tagil
DIR_MAKEFILE := ${realpath .}
DIR_TAGIL := $(DIR_MAKEFILE)

ifneq ($(shell test -e $(DIR_MAKEFILE)/env.mk && echo yes),yes)
DIR_TAGIL := $(DIR_MAKEFILE)/tagil
endif

# Including according to anchor directory
include $(DIR_TAGIL)/utils.mk
include $(DIR_TAGIL)/log.mk
include $(DIR_TAGIL)/help.mk
include $(DIR_TAGIL)/info.mk
include $(DIR_TAGIL)/env.mk
include $(DIR_TAGIL)/meta.mk
include $(DIR_TAGIL)/compile.mk

help: $(HELP)
info: $(INFO)
.PHONY: help info

