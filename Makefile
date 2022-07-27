#
# This makefile call the tub/main.mk
# and controlles the prebuild
#
.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

export REPOROOT:=${shell git rev-parse --show-toplevel}
SCRIPT:=$(REPOROOT)/tub
MAIN_MK:=$(REPOROOT)/tub/main.mk
MAIN_FLAGS+=REPOROOT=$(REPOROOT)
MAIN_FLAGS+=RECURSIVE=1
MAIN_FLAGS+=PREBUILD_MK=$(MAIN_MK)
MAIN_FLAGS+=-f $(MAIN_MK)
MAIN_FLAGS+=--no-print-directory

ifeq (,${stript $(MAKECMDGOALS)})
help:
	$(MAKE) $(MAIN_FLAGS) $@
endif


match=${shell $(SCRIPT)/check_regex.d $@ -r'^(env-\w+|env|help-\w+|help|clean-\w+|clean|proper-\w+|proper|ddeps|dfiles|dstep)$$'}

cloned=${sheel $(SCRIPT)/check_module. $$(REPOROOT)}

ifdef RECURSIVE
${error This makefile should not be called recursively}
endif

xxx:
	echo $(cloned)

%:
	@
	echo $(cloned)
	if [ -z "${call match,$@}" ]; then
	$(MAKE) $(MAIN_FLAGS) prebuild
	fi
	$(MAKE) $(MAIN_FLAGS) $@
