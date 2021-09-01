# Choosing root directory
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)
TUB_MODE := Rooted

ifneq ($(shell test -e $(DIR_MAKEFILE)/env.mk && echo yes),yes)
DIR_TUB := $(DIR_MAKEFILE)/tub
endif

DIR_ROOT := ${abspath ${DIR_TUB}/../}
DIR_TUB_ROOT := $(DIR_ROOT)

ifneq ($(shell test -e $(DIR_TUB_ROOT)/tubroot && echo yes),yes)
DIR_TUB_ROOT := $(DIR_MAKEFILE)/tub
TUB_MODE := Isolated
TUB_MODE_ISOLATED := 1
endif

# Inlclude local setup
-include $(DIR_ROOT)/local.mk

# Including according to anchor directory
include $(DIR_TUB)/utils.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk
include $(DIR_TUB)/env.mk

main: help
help: $(HELP)

update:
	@cd $(DIR_TUB); git checkout .
	@cd $(DIR_TUB); git pull origin --force

checkout/%: 
	@cd $(DIR_TUB); git checkout $(*)
	@cd $(DIR_TUB); git pull origin --force
run:
	@cp $(DIR_TUB)/run $(DIR_ROOT)/run

derun:
	@rm $(DIR_ROOT)/run

include $(DIR_TUB)/add.mk
include $(DIR_TUB)/revision.mk
include $(DIR_TUB)/unit.mk
# include $(DIR_TUB)/compile.mk
include $(DIR_TUB)/clean.mk

ifeq ($(TUB_MODE_ISOLATED),1)
# Include context of current unit in isolate mode
include $(DIR_ROOT)/context.mk
else
COMPILE_TARGETS := $(MAKECMDGOALS)
COMPILE_TARGETS_DIRS := ${foreach COMPILE_TARGET, $(COMPILE_TARGETS), $(subst libtagion,lib-,$(COMPILE_TARGET))}
COMPILE_TARGETS_DIRS := ${foreach COMPILE_TARGET, $(COMPILE_TARGETS_DIRS), $(subst tagion,bin-,$(COMPILE_TARGET))}
${foreach COMPILE_TARGETS_DIR, $(COMPILE_TARGETS_DIRS), ${eval include $(DIR_SRC)/$(COMPILE_TARGETS_DIR)/context.mk}}
endif

.PHONY: help info
.SECONDARY: