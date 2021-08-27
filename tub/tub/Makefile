# Choosing anchor directory between root of the lab and tagil
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)

ifneq ($(shell test -e $(DIR_MAKEFILE)/env.mk && echo yes),yes)
DIR_TUB := $(DIR_MAKEFILE)/tub
endif

DIR_TUB_ROOT := ${realpath ${DIR_TUB}/../}

${info $(DIR_TUB_ROOT)}

# Inlclude local setup
-include $(DIR_TUB_ROOT)/local.mk

# Including according to anchor directory
include $(DIR_TUB)/utils.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk
include $(DIR_TUB)/revision.mk
include $(DIR_TUB)/env.mk
include $(DIR_TUB)/add.mk
include $(DIR_TUB)/compile.mk
include $(DIR_TUB)/clean.mk

install:
	@$(DIR_TUB)/install

update:
	@cd $(DIR_TUB); git checkout .
	@cd $(DIR_TUB); git pull origin --force

help: $(HELP)
info: $(INFO)
.PHONY: help info
.SECONDARY: