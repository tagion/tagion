# DO NOT MODIFY
# This file is generated, and can be replaced at any moment
.NOTPARALLEL:

DROOT:=${shell git rev-parse --show-toplevel}
MAIN_MK=tub/main.mk
MAIN_FLAGS+=MAIN_FLAGS=$(MAKEFLAGS) PREBUILD_MK=$(MAIN_MK) DROOT=$(DROOT)
MAIN_FLAGS+=-f $(MAIN_MK)
MAIN_FLAGS+=--no-print-directory


# .SECONDARY:
# .ONESHELL:

# test73:
# 	@echo "$(MAKECMDGOALS)"
# 	@echo "$(MAKEFLAGS)"
# env help clean proper: main

# env-%: main

# help-%: main

# clean-%: main

# proper-%: main

# main:
# 	@echo $(MAIN_FLAGS) $(MAKECMDGOALS)
# 	$(MAKE) $(MAIN_FLAGS) $(MAKECMDGOALS)


CMDTARGETS+=env env-%
CMDTARGETS+=help help-%
CMDTARGETS+=clean clean-%
CMDTARGETS+=proper proper-%

.PHONY: $(CMDTARGETS)

#TEST=${filter $(CMDTARGETS), $(MAKECMDGOALS)}

ifneq ($(MAKECMDGOALS),${filter $(CMDTARGETS),$(MAKECMDGOALS)})
%:
	$(MAKE) $(MAIN_FLAGS) prebuild
	@echo MAIN $(MAIN_FLAGS) $(MAKECMDGOALS)
	$(MAKE) $(MAIN_FLAGS) $(MAKECMDGOALS)
else
%:
	$(MAKE) $(MAIN_FLAGS) $(MAKECMDGOALS)
endif
