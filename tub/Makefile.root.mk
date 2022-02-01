# DO NOT MOFIFY
# This file is generated, and can be replaced at any moment

.SECONDARY:

-include tub/main.mk

ifndef DTUB
ifdef RECURSIVE
define ERRORMSG
Error:
The build tools tub has not been installed
Try to run

git submodule update --init --recursive
tub/gits.d --config

endef
${error $(ERRORMSG)}

endif

all: doit

# The following replaces ./tub/setup:
%:
	@git submodule update --init --recursive
	@$(MAKE) RECURSIVE=1 gitconfig
	@$(MAKE) RECURSIVE=1 $@
endif
