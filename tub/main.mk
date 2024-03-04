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

#
# Used for temp scripts
#
TMP_FILE=${shell mktemp -q /tmp/make.XXXXXXXX}

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

include $(TARGETS)/commands.mk
include $(TARGETS)/compiler.mk

#
# Native platform
#
# This is the HOST target platform
#
ifdef USEHOST
HOST:=$(USEHOST)
else
HOST:=${call join-with,-,$(GETARCH) $(GETHOSTOS) $(GETOS)}
endif
PLATFORM:=$(HOST)

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
include $(TARGETS)/host.mk
include $(TARGETS)/platform.mk
include $(TARGETS)/auxiliary.mk
include $(TARGETS)/cov.mk

#
# Packages
#
include $(TARGETS)/dstep.mk
include $(TARGETS)/bins.mk
include $(TARGETS)/format.mk
include $(TARGETS)/dscanner.mk

include $(DTUB)/compile.mk

#
# Include all unit make files
#
-include $(DSRC)/wrap-*/context.mk
-include $(DSRC)/fork-*/context.mk
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

#
# Testbench
#
include $(DTUB)/testbench/unittest.mk
include $(DTUB)/testbench/collider.mk
include $(DTUB)/testbench/test.mk
include $(DTUB)/testbench/citest.mk
include $(DTUB)/testbench/release.mk

#
# Install main tool
#
include $(TARGETS)/revision.mk
include $(TARGETS)/install.mk

#
# Install doc tool
#
include $(TARGETS)/doc.mk

#
# Enable cleaning
#
include $(DTUB)/clean.mk

#
# Help
#
include $(DTUB)/help.mk


#
# Road runner
#
include $(TARGETS)/trunk.mk

#
# WASI druntime 
# Used to test the TVM
#
include $(TARGETS)/wasi.mk 
include $(TARGETS)/tauon.mk 

