# Git
GIT_HASH ?= ${shell git rev-parse HEAD}
GIT_INFO ?= ${shell git config --get remote.origin.url}
GIT_REVNO ?= ${shell git log --pretty=format:'%h' | wc -l}

# Root project directory
DIR_LAB ?= ${shell git rev-parse --show-toplevel}
DIR_LAB_SRC ?= $(DIR_LAB)/src

# Directory for libs and bins
DIR_LIBS ?= $(DIR_LAB_SRC)/libs
DIR_BINS ?= $(DIR_LAB_SRC)/bins

# Directory for make scripts
DIR_SCRIPTS ?= $(DIR_LAB_SRC)/scripts

# Pointer to current file directory
DIR_SELF = $(dir $(lastword $(MAKEFILE_LIST)))

INFO += info-env
info-env:
	$(call log.open, info :: env)
	$(call log.kvp, GIT_HASH, $(GIT_HASH))
	$(call log.kvp, GIT_INFO, $(GIT_INFO))
	$(call log.kvp, GIT_REVNO, $(GIT_REVNO))
	$(call log.separator)
	$(call log.kvp, DIR_LAB, $(DIR_LAB))
	$(call log.kvp, DIR_LAB_SRC, $(DIR_LAB_SRC))
	$(call log.separator)
	$(call log.kvp, DIR_SCRIPTS, $(DIR_SCRIPTS))
	$(call log.separator)
	$(call log.kvp, DIR_LIBS, $(DIR_LIBS))
	$(call log.kvp, DIR_BINS, $(DIR_BINS))
	$(call log.close)

include $(DIR_SELF)/command.mk