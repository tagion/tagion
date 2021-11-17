main: help

# Defining absolute Root and Tub directories
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)/tub
DIR_ROOT := ${abspath ${DIR_TUB}/../}

include $(DIR_TUB)/rex.mk
include $(DIR_TUB)/git.mk

# Local setup, ignored by git
-include $(DIR_ROOT)/local.*.mk
-include $(DIR_ROOT)/local.mk

# Secondary tub functionality
include $(DIR_TUB)/ways.mk
include $(DIR_TUB)/vars.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk

FCONFIGURE := gen.configure.mk
FCONFIGURETEST := gen.configure.test.mk

INCLFLAGS := ${addprefix -I,${shell ls -d $(DSRC)/*/ 2> /dev/null || true | grep -v wrap-}}

UNITS_BIN := ${shell ls $(DSRC) | grep bin-}
UNITS_LIB := ${shell ls $(DSRC) | grep lib-}
UNITS_WRAP := ${shell ls $(DSRC) | grep wrap-}

# Basic clean config
TOCLEAN += $(DTMP)
TOCLEAN += $(DBIN)

# Enable cloning, if BRANCH is known
ifdef BRANCH
include $(DSRC)/**/context.mk

include $(DIR_TUB)/clone.mk
else
$(call warning, Can not clone when BRANCH is not defined, make branch-<branch>)
endif

# Enable configuration compilation
ifeq ($(MAKECMDGOALS),configure)
include $(DSRC)/**/context.mk

include $(DIR_TUB)/configure.mk
else
# Include all unit make files
include $(DSRC)/**/*.mk

include $(DIR_TUB)/compile.mk
endif

# Enable cleaning
include $(DIR_TUB)/clean.mk

# Disabling removal of intermidiate targets
.SECONDARY: