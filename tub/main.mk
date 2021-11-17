main: help

# Defining absolute Root and Tub directories
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)/tub
DIR_ROOT := ${abspath ${DIR_TUB}/../}

# Disabling removal of intermidiate targets
# .SECONDARY:

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
include $(DIR_TUB)/common.mk
include $(DIR_TUB)/clean.mk

# Unit make files
include $(DIR_SRC)/**/*.mk

# Core tub functionality
ifdef BRANCH
include $(DIR_TUB)/clone.mk
else
$(call warning, Can not clone when BRANCH is not defined, make branch-<branch>)
endif

include $(DIR_TUB)/configure.mk
include $(DIR_TUB)/compile.mk





