main: help

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
include $(DIR_TUB)/list.mk
include $(DIR_TUB)/utils.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk
include $(DIR_TUB)/env.mk

help: $(HELP)

update:
	@cd $(DIR_TUB); git checkout .
	@cd $(DIR_TUB); git pull origin --force

checkout/%: 
	@cd $(DIR_TUB); git checkout $(*)
	@cd $(DIR_TUB); git pull origin --force

# 
# Switches for extra features
# 
enable-run:
	@cp $(DIR_TUB)/run $(DIR_ROOT)/run

disable-run:
	@rm $(DIR_ROOT)/run

# include $(DIR_TUB)/add.mk
include $(DIR_TUB)/ways.mk
# include $(DIR_TUB)/unit.mk
include $(DIR_TUB)/clean.mk

# 
# Determining Target
# 

# The logic below is for compile targets, which contain 'tagion'
# Tub has macros in 'unit.mk' to generate required targets
# and resolve all their dependencies
COMPILE_UNIT_TARGETS := ${filter libtagion% tagion% testscope-libtagion% testall-libtagion%, $(MAKECMDGOALS)}
ifdef COMPILE_UNIT_TARGETS

# Determine the test mode between:
# 'scope' - unit tests from the tagion unit only
# 'all' - unit tests from the tagion unit and its tagion unit dependencies (wraps are not tested)
ifeq "${findstring testscope-, $(COMPILE_UNIT_TARGETS)}" "testscope-"
COMPILE_UNIT_TEST := 1
COMPILE_UNIT_TEST_SCOPE := 1
COMPILE_UNIT_TARGETS := ${subst testscope-,,$(COMPILE_UNIT_TARGETS)}
endif
ifeq "${findstring testall-, $(COMPILE_UNIT_TARGETS)}" "testall-"
COMPILE_UNIT_TEST := 1
COMPILE_UNIT_TEST_ALL := 1
COMPILE_UNIT_TARGETS := ${subst testsall-,,$(COMPILE_UNIT_TARGETS)}
endif

# Replace target prefixes with dir prefixes to include correct initial context files
COMPILE_UNIT_TARGETS := ${subst libtagion,lib-,$(COMPILE_UNIT_TARGETS)}
COMPILE_UNIT_TARGETS := ${subst tagion,bin-,$(COMPILE_UNIT_TARGETS)}
${foreach COMPILE_UNIT_TARGETS_DIR, $(COMPILE_UNIT_TARGETS), ${eval include $(DIR_SRC)/$(COMPILE_UNIT_TARGETS_DIR)/context.mk}}

endif

.PHONY: help info
.SECONDARY: