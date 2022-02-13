#
# This makefile call the tub/main.mk
# and controlles the prebuild
#
.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

DROOT:=${shell git rev-parse --show-toplevel}
SCRIPT:=$(DROOT)/tub
MAIN_MK:=$(DROOT)/tub/main.mk
MAIN_FLAGS+=DROOT=$(DROOT)
MAIN_FLAGS+=RECURSIVE=1
MAIN_FLAGS+=PREBUILD_MK=$(MAIN_MK)
MAIN_FLAGS+=-f $(MAIN_MK)
MAIN_FLAGS+=--no-print-directory

ifeq (,${stript $(MAKECMDGOALS)})
help:
	$(MAKE) $(MAIN_FLAGS) $@
endif


match=${shell $(SCRIPT)/check_regex.d $@ -r'^(env-\w+|env|help-\w+|help|clean-\w+|clean|proper-\w+|proper|ddeps|dfiles|dstep)$$'}

ifdef RECURSIVE
${error This makefile should to be call recursive}
endif

%:
	@
	if [ -z "${call match,$@}" ]; then
	$(MAKE) $(MAIN_FLAGS) prebuild
	fi
	$(MAKE) $(MAIN_FLAGS) $@
