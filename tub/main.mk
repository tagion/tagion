main: help

# Defining absolute Root and Tub directories
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)/tub
DIR_ROOT := ${abspath ${DIR_TUB}/../}

# Disabling removal of intermidiate targets
.SECONDARY:

include $(DIR_TUB)/configure.mk
include $(DIR_TUB)/rex.mk
include $(DIR_TUB)/git.mk

# Local setup, ignored by git
-include $(DIR_ROOT)/local.*.mk
-include $(DIR_ROOT)/local.mk

# Secondary tub functionality
include $(DIR_TUB)/ways.mk
include $(DIR_TUB)/vars.mk
include $(DIR_TUB)/debug.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk

ifdef BRANCH
# Core tub functionality
include $(DIR_TUB)/resolve/module.mk
include $(DIR_TUB)/compile/module.mk
else
$(call print, Compilation module disabled, Why: BRANCH is not defined, Fix: make checkout-<branch> OR make branch-<branch>, Example: make checkout-peppa)
endif





