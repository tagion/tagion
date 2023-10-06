#
# This makefile call the tub/main.mk
# and controlles the prebuild
#
.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

export REPOROOT:=${shell git rev-parse --show-toplevel}
SCRIPT:=$(REPOROOT)/tub
# MAIN_MK:=
include $(REPOROOT)/tub/main.mk
# MAIN_FLAGS+=REPOROOT=$(REPOROOT)
# MAIN_FLAGS+=RECURSIVE=1
# MAIN_FLAGS+=PREBUILD_MK=$(MAIN_MK)
# MAIN_FLAGS+=-f $(MAIN_MK)
# MAIN_FLAGS+=--no-print-directory

# ifeq (,${stript $(MAKECMDGOALS)})
# help:
# 	$(MAKE) $(MAIN_FLAGS) $@
# endif


# match=${shell $(SCRIPT)/check_regex.d $@ -r'^(list-\w+|env-\w+|env|help-\w+|help|clean-\w+|clean|proper-\w+|proper|dscanner-\w+|ddeps|dfiles|dstep|format|ddoc|ddox|servedocs)$$'}

# ifdef RECURSIVE
# ${error This makefile should not be called recursively}
# endif

# %:
# 	@
# 	git submodule update
# 	# if [ -n "$(SCRIPT)/check_submodule.d $(REPOROOT)" ]; then
# 	# git submodule update --init --depth=1
# 	# fi
# 	# if [ -z "${call match,$@}" ]; then
# 	# $(MAKE) $(MAIN_FLAGS) prebuild
# 	# fi
# 	$(MAKE) $(MAIN_FLAGS) $@
