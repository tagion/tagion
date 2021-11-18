main: help

# Defining absolute Root and Tub directories
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)/tub
DIR_ROOT := ${abspath ${DIR_TUB}/../}

include $(DIR_TUB)/rex.mk
include $(DIR_TUB)/git.mk
include $(DIR_TUB)/utils.mk

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

# Enable cloning, if BRANCH is known
ifeq ($(findstring clone,$(MAKECMDGOALS)),clone)
ifdef BRANCH
-include $(DSRC)/**/context.mk

include $(DIR_TUB)/clone.mk
else
$(call warning, Can not clone when BRANCH is not defined, make branch-<branch>)
endif
else
${shell $(MKDIR) $(DIR_ROOT)/src}

INCLFLAGS := ${addprefix -I,${shell ls -d $(DSRC)/*/ 2> /dev/null || true | grep -v wrap-}}

UNITS_BIN := ${shell ls $(DSRC) | grep bin-}
UNITS_LIB := ${shell ls $(DSRC) | grep lib-}
UNITS_WRAP := ${shell ls $(DSRC) | grep wrap-}

# Include all unit make files
include $(DSRC)/wrap-*/context.mk
include $(DSRC)/lib-*/context.mk
include $(DSRC)/bin-*/context.mk

# Enable configuration compilation
ifeq ($(findstring configure,$(MAKECMDGOALS)),configure)
include $(DIR_TUB)/configure.mk
else
-include $(DSRC)/lib-*/gen.*.mk
-include $(DSRC)/bin-*/gen.*.mk
include $(DIR_TUB)/compile.mk
endif
endif

# Enable cleaning
include $(DIR_TUB)/clean.mk

# Disabling removal of intermidiate targets
.SECONDARY:

env: $(MAKE_SHOW_ENV)