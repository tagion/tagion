
.SUFFIXES:
.SECONDARY:
.ONESHELL:
.SECONDEXPANSION:

# Common variables
# Override PRECMD= to see output of all commands
PRECMD ?= @

main: help

#
# Defining absolute Root and Tub directories
#
export DSRC := $(abspath $(REPOROOT)/src)
export DTUB := $(abspath $(REPOROOT)/tub)
ifndef REPOROOT
${error REPOROOT must be defined}
endif
#export REPOROOT := ${abspath ${DTUB}/../}

ifeq (prebuild,$(MAKECMDGOALS))
PREBUILD=1
endif

#
# Local config, ignored by git
#
-include $(REPOROOT)/local.*.mk
-include $(REPOROOT)/local.mk
include $(DTUB)/utilities/dir.mk
include $(DTUB)/utilities/log.mk

include $(DTUB)/tools/*.mk
include $(DTUB)/config/git.mk
include $(DTUB)/config/commands.mk

prebuild:
	$(PRECMD)
	${foreach wrap,$(WRAPS),$(MAKE) $(MAKEOVERRIDES) -f $(PREBUILD_MK) $(wrap);}
	git submodule update --recursive
	$(MAKE) $(MAKEOVERRIDES) -f $(PREBUILD_MK) dstep
	$(MAKE) $(MAKEOVERRIDES) -f $(PREBUILD_MK) ddeps



#
# Native platform
#
# This is the HOST target platform
#
HOST=${call join-with,-,$(GETARCH) $(GETHOSTOS) $(GETOS)}
PLATFORM?=$(HOST)

#
# Platform
#
include $(DTUB)/config/dirs.mk
#
# Prebuild
#
include $(DTUB)/config/prebuild.mk
ifndef PREBUILD
-include $(DBUILD)/gen.dfiles.mk
-include $(DBUILD)/gen.ddeps.mk
endif

-include $(REPOROOT)/platform.*.mk

#
# Secondary tub functionality
#
include $(DTUB)/ways.mk
include $(DTUB)/gitconfig.mk
include $(DTUB)/config/submodules.mk
include $(DTUB)/config/druntime.mk
include $(DTUB)/config/submake.mk
include $(DTUB)/config/host.mk
include $(DTUB)/config/cross.mk
include $(DTUB)/config/platform.mk
include $(DTUB)/config/auxiliary.mk
include $(DTUB)/devnet/devnet.mk

#
# Packages
#

include $(DTUB)/config/compiler.mk
include $(DTUB)/config/dstep.mk
include $(DTUB)/config/ddeps.mk

include $(DTUB)/compile.mk

#
# Include all unit make files
#
-include $(DSRC)/wrap-*/context.mk
-include $(DSRC)/lib-*/context.mk
-include $(DSRC)/bin-*/context.mk

#
# Root config
#
-include $(REPOROOT)/config.*.mk
-include $(REPOROOT)/config.mk

include $(DTUB)/config/ldc-build-runtime.mk

#
# Testbench
#
include $(DTUB)/config/testbench.mk


#
# Enable cleaning
#
include $(DTUB)/clean.mk

#
# Help
#
include $(DTUB)/help.mk

run: tagionwave
	cd $(DBIN);
	rm -fR data; mkdir data;
	script -c "./tagionwave $(DRTFALGS) -N 7 -t 200" tagionwave_script.log

mode1: tagionwave
	cd $(DBIN)
	rm -f tagionrun.sh tagionwave.json
	ln -s ../../../tagionwave.json
	ln -s ../../../tagionrun.sh
	./tagionrun.sh
