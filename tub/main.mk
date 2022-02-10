
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
export DSRC := $(abspath $(DROOT)/src)
export DTUB := $(abspath $(DROOT)/tub)
ifndef DROOT
${error DROOT must be defined}
endif
#export DROOT := ${abspath ${DTUB}/../}

ifeq (prebuild,$(MAKECMDGOALS))
PREBUILD=1
endif

#
# Local config, ignored by git
#
-include $(DROOT)/local.*.mk
-include $(DROOT)/local.mk
include $(DTUB)/utilities/dir.mk
include $(DTUB)/utilities/log.mk

include $(DTUB)/tools/*.mk
include $(DTUB)/config/git.mk
include $(DTUB)/config/commands.mk

prebuild:
	$(PRECMD)
	$(MAKE) $(MAIN_FLAGS) -f $(PREBUILD_MK) secp256k1
	$(MAKE) $(MAIN_FLAGS) -f $(PREBUILD_MK) p2pgowrapper
	$(MAKE) $(MAIN_FLAGS) -f $(PREBUILD_MK) openssl
	$(MAKE) $(MAIN_FLAGS) -f $(PREBUILD_MK) dstep
	$(MAKE) $(MAIN_FLAGS) -f $(PREBUILD_MK) ddeps



#
# Native platform
#
# This is the HOST target platform
#
HOST_PLATFORM=${call join-with,-,$(GETARCH) $(GETHOSTOS) $(GETOS)}
PLATFORM?=$(HOST_PLATFORM)

#
# Platform
#
include $(DTUB)/config/dirs.mk
#
# Prebuild
#
include $(DTUB)/config/prebuild.mk
# ifdef $(DFILES)
# -include $(DBUILD)/gen.dfiles.mk
# -include $(DBUILD)/gen.ddeps.mk
# endif

-include $(DROOT)/platform.*.mk

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
-include $(DROOT)/config.*.mk
-include $(DROOT)/config.mk


#
# Enable cleaning
#
include $(DTUB)/clean.mk

#
# Help
#
include $(DTUB)/help.mk
