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
export TARGETS := $(DTUB)/targets
export BDD := $(abspath $(REPOROOT)/bdd)
ifndef REPOROOT
${error REPOROOT must be defined}
endif
#export REPOROOT := ${abspath ${DTUB}/../}

ifeq (prebuild,$(MAKECMDGOALS))
PREBUILD=1
endif

#
# Used for temp scripts
#
TMP_FILE=${shell mktemp -q /tmp/make.XXXXXXXX.sh}

#
# Local config, ignored by git
#
-include $(REPOROOT)/local.*.mk
-include $(REPOROOT)/local.mk
include $(REPOROOT)/default.mk
include $(DTUB)/testbench/default.mk
include $(DTUB)/utilities/utils.mk
include $(DTUB)/utilities/dir.mk
include $(DTUB)/utilities/log.mk

include $(DTUB)/tools/*.mk
include $(TARGETS)/git.mk
include $(TARGETS)/commands.mk

prebuild:
	$(PRECMD)
	git submodule update --recursive
	${foreach wrap,$(WRAPS),$(MAKE) $(MAKEOVERRIDES) -f $(PREBUILD_MK) $(wrap);}
	$(MAKE) $(MAKEOVERRIDES) -f $(PREBUILD_MK) revision
	$(MAKE) $(MAKEOVERRIDES) -f $(PREBUILD_MK) dstep
#	$(MAKE) $(MAKEOVERRIDES) -f $(PREBUILD_MK) ddeps

env-prebuild:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, PREBUILD_MK, $(PREBUILD_MK)}
	${call log.env, WRAPS, $(WRAPS)}
	${call log.close}

#
# Native platform
#
# This is the HOST target platform
#
ifdef USEHOST
HOST=$(USEHOST)
else
HOST=${call join-with,-,$(GETARCH) $(GETHOSTOS) $(GETOS)}
endif
PLATFORM?=$(HOST)

#
# Platform
#
include $(DTUB)/targets/dirs.mk
#
# Prebuild
#
-include $(REPOROOT)/platform.*.mk

#
# Secondary tub functionality
#
include $(DTUB)/ways.mk
include $(DTUB)/gitconfig.mk
include $(TARGETS)/submodules.mk
# include $(TARGETS)/druntime.mk
include $(TARGETS)/submake.mk
include $(TARGETS)/host.mk
include $(TARGETS)/cross.mk
include $(TARGETS)/platform.mk
include $(TARGETS)/auxiliary.mk
include $(DTUB)/devnet/devnet.mk

#
# Packages
#
include $(TARGETS)/compiler.mk
include $(TARGETS)/dstep.mk
#include $(TARGETS)/ddeps.mk
include $(TARGETS)/bins.mk
include $(TARGETS)/format.mk
include $(TARGETS)/dscanner.mk
include $(TARGETS)/libs.mk

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

#
# Profile setting
#
include $(TARGETS)/profile.mk
include $(TARGETS)/valgrind.mk

include $(TARGETS)/ldc-build-runtime.mk

#
# Testbench
#
include $(DTUB)/testbench/unittest.mk
include $(TARGETS)/unitthreaded.mk
include $(DTUB)/testbench/wallets.mk
include $(DTUB)/testbench/mode0.mk
include $(DTUB)/testbench/mode1.mk
include $(DTUB)/testbench/collider.mk
include $(DTUB)/testbench/reporter.mk
include $(DTUB)/testbench/test.mk

#
# Install main tool
#
include $(TARGETS)/revision.mk
include $(TARGETS)/install.mk

#
# Install doc tool
#
include $(TARGETS)/ddoc.mk

#
# Enable cleaning
#
include $(DTUB)/clean.mk

#
# Help
#
include $(DTUB)/help.mk
