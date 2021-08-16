# Choosing anchor directory between root of the lab and tagil
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)

ifneq ($(shell test -e $(DIR_MAKEFILE)/env.mk && echo yes),yes)
DIR_TUB := $(DIR_MAKEFILE)/tub
endif

# Including according to anchor directory
include $(DIR_TUB)/utils.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk
include $(DIR_TUB)/info.mk
include $(DIR_TUB)/env.mk
include $(DIR_TUB)/add.mk
include $(DIR_TUB)/meta.mk
include $(DIR_TUB)/blueprint.mk
include $(DIR_TUB)/compile.mk

help: $(HELP)
info: $(INFO)
.PHONY: help info
.SECONDARY: