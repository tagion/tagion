main: | submodules help

# Common variables
# Override PRECMD= to see output all commands
PRECMD ?= @
SUBMAKE_PARALLEL := -j

# Git
GIT_ORIGIN := "git@github.com:tagion"
GIT_SUBMODULES :=

# Defining absolute Root and Tub directories
DMAKEFILE := ${realpath .}
DTUB := $(DMAKEFILE)/tub
DROOT := ${abspath ${DTUB}/../}

include $(DTUB)/rex.mk
include $(DTUB)/git.mk
include $(DTUB)/gitconfig.mk
include $(DTUB)/utils.mk

# Root setup
-include $(DROOT)/tubroot.mk

# Local setup, ignored by git
-include $(DROOT)/local.*.mk
-include $(DROOT)/local.mk

# Secondary tub functionality
include $(DTUB)/ways.mk
include $(DTUB)/host.mk
include $(DTUB)/commands.mk
include $(DTUB)/cross.mk
include $(DTUB)/dirs.mk
include $(DTUB)/compiler.mk
include $(DTUB)/log.mk
include $(DTUB)/help.mk

FCONFIGURE := gen.configure.mk
FCONFIGURETEST := gen.configure.test.mk

# Enable cloning, if BRANCH is known
ifeq ($(findstring clone,$(MAKECMDGOALS)),clone)
ifdef BRANCH
-include $(DSRC)/**/context.mk

include $(DTUB)/clone.mk
else
$(call warning, Can not clone when BRANCH is not defined, make branch-<branch>)
endif
else
${shell $(MKDIR) $(DROOT)/src}

INCLFLAGS := ${addprefix -I,${shell ls -d $(DSRC)/*/ 2> /dev/null || true | grep -v wrap-}}

UNITS_BIN := ${shell ls $(DSRC) | grep bin-}
UNITS_LIB := ${shell ls $(DSRC) | grep lib-}
UNITS_WRAP := ${shell ls $(DSRC) | grep wrap-}

# Include all unit make files
-include $(DSRC)/wrap-*/context.mk
-include $(DSRC)/lib-*/context.mk
-include $(DSRC)/bin-*/context.mk

# Enable configuration compilation
ifeq ($(findstring configure,$(MAKECMDGOALS)),configure)
include $(DTUB)/configure.mk
else
-include $(DSRC)/lib-*/gen.*.mk
-include $(DSRC)/bin-*/gen.*.mk
include $(DTUB)/compile.mk
endif
endif

# Enable cleaning
include $(DTUB)/clean.mk

# Disabling removal of intermidiate targets
.SECONDARY:

env: $(MAKE_ENV)

submodules: $(DROOT)/submodule.init
	$(PRECMD)git submodule update

$(DROOT)/submodule.init:
	$(PRECMD)git submodule init
