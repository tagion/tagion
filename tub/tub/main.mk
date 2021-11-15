main: help

# Tub protocol version that modules must explicitly support
TUB_PROTOCOL := 5

# Defining absolute Root and Tub directories
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)/tub
DIR_ROOT := ${abspath ${DIR_TUB}/../}

# Tub can run in Rooted and Isolated modes
# 	Rooted - flat unit structure. Used for development
# 	Isolated - modules treated as dependencies, installed in sub-folder. Used in CI pipelines
TUB_MODE := Rooted

# Define directory to resolve /src and /build against
DIR_TUB_ROOT := $(DIR_ROOT)

ifneq ($(shell test -e $(DIR_TUB_ROOT)/tubroot && echo yes),yes)
DIR_TUB_ROOT := $(DIR_MAKEFILE)/tub

TUB_MODE := Isolated
TUB_MODE_ISOLATED := 1
endif

# Disabling removal of intermidiate targets
.SECONDARY:

include $(DIR_TUB)/configure.mk
include $(DIR_TUB)/rex.mk
include $(DIR_TUB)/git.mk

# Local setup, ignored by git
-include $(DIR_ROOT)/local.*.mk
-include $(DIR_ROOT)/local.mk

# Secondary tub functionality
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





