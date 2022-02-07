# DO NOT MODIFY
# This file is generated, and can be replaced at any moment

.SECONDARY:
.ONESHELL:

test73:
	@echo "$(MAKECMDGOALS)"
	@echo "$(MAKEFLAGS)"

include tub/main.mk

# Hack to get tagionwave to build
#include src/bin-wave/build.mk
#include src/lib-mobile/build.mk

# ifndef DTUB
# ifdef RECURSIVE
# define ERRORMSG
# Error:
# The build tools tub has not been installed
# Try to run

# git submodule update --init --recursive
# tub/gits.d --config

# endef
# ${error $(ERRORMSG)}

# endif

# # all: doit

# # The following replaces ./tub/setup:
# # %:
# # 	@git submodule update --init --recursive
# # 	@$(MAKE) RECURSIVE=1 setup
# # 	@$(MAKE) RECURSIVE=1 $@

# endif

# test99:
# 	@echo $@

#test77: $(DOBJ)/lib-services/tagion/services/TagionFactory.o

#test88: 	/home/carsten/work/cross_regression/build/x86_64-unknown-linux/tmp/libsecp256k1.a

#test75: /home/carsten/work/cross_regression/src/lib-p2pgowrapper/p2p/connection.d

#GEN_DDEPS_MK:=$(DBUILD)/gen.ddeps.mk
# $(GEN_DDEPS_MK): /home/carsten/work/cross_regression/src/lib-p2pgowrapper/p2p/node.d | $(DIFILES)

#$(GEN_DDEPS_MK): $(DIFILES_DEPS)

# ifndef DOBJALL
# PREBUILD:=prebuild
# endif

# prebuild:
# 	$(MAKE) $(GEN_DDEPS_MK)

# .phony: prebuild

# ifndef DOBJALL
# test76:
# 	$(MAKE) $(GEN_DDEPS_MK)
# 	$(MAKE) test76
# else
#test76: $(PREBUILD)
#test76: $(DOBJALL)
# endif

#test78:
#	echo $(DIFILES)
#	echo DIFILES_DEPS=$(DIFILES_DEPS)

myprog: .EXTRA_PREREQS = $(CC)
