.SECONDARY:
.ONESHELL:

main: help

# Common variables
# Override PRECMD= to see output of all commands
PRECMD ?= @

# Defining absolute Root and Tub directories
DSRC := $(realpath src)
DTUB := $(realpath tub)
DROOT := ${abspath ${DTUB}/../}

include $(DTUB)/utilities/dir.mk

# Root config
-include $(DROOT)/config.*.mk
-include $(DROOT)/config.mk

# Local config, ignored by git
-include $(DROOT)/local.*.mk
-include $(DROOT)/local.mk

# Secondary tub functionality
include $(DTUB)/ways.mk
include $(DTUB)/config/submake.mk
include $(DTUB)/config/git.mk
include $(DTUB)/config/host.mk
include $(DTUB)/config/commands.mk
include $(DTUB)/config/cross.mk
include $(DTUB)/config/dirs.mk
include $(DTUB)/config/compiler.mk
include $(DTUB)/config/env.mk
include $(DTUB)/utilities/log.mk # TODO: Deprecate

# Help
include $(DTUB)/help.mk

# Enable cloning, if BRANCH is known
ifeq ($(findstring clone,$(MAKECMDGOALS)),clone)
ifdef BRANCH
-include $(DSRC)/**/context.mk

include $(DTUB)/clone/clone.mk
else
$(call warning, Can not clone when BRANCH is not defined, make branch-<branch>)
endif
else
include $(DTUB)/config/units.mk

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


setup: $(DROOT)/.root
	$(PRECMD)
	touch $(DROOT)/.root
	echo "Installing local git aliases..."
	$(DTUB)/scripts/gitconfig
	echo
	git move ${shell git rev-parse --abbrev-ref HEAD} &> /dev/null
	echo "Git branches:"
	git sbranch
	touch $(DROOT)/.root