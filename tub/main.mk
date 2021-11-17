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
include $(DIR_TUB)/debug.mk
include $(DIR_TUB)/log.mk
include $(DIR_TUB)/help.mk
include $(DIR_TUB)/common.mk
include $(DIR_TUB)/clean.mk

INCLFLAGS := ${addprefix -I,${shell ls -d $(DIR_SRC)/*/ 2> /dev/null || true | grep -v wrap-}}
INCLFLAGS += ${addprefix -I,${shell ls -d $(DIR_BUILD_WRAPS)/*/lib 2> /dev/null || true}}

# Basic clean config
TOCLEAN += $(DTMP)/libs
TOCLEAN += $(DBIN)/bins

ifdef FCONFIGURE
TOCLEAN += $(DIR_SRC)/**/$(FCONFIGURE)
endif

# Unit make files
include $(DIR_SRC)/**/*.mk

# Core tub functionality
ifdef BRANCH
include $(DIR_TUB)/clone.mk
else
$(call warning, Can not clone when BRANCH is not defined, make branch-<branch>)
endif

ifeq ($(MAKECMDGOALS),configure)
include $(DIR_TUB)/configure.mk
else
include $(DIR_TUB)/compile.mk
endif

# Disabling removal of intermidiate targets
.SECONDARY: