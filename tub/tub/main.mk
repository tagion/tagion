# TODO: Test in isolated mode
# TODO: Test auto adding dependencies (ensure correct branching as well)
# TODO: Add revision
# TODO: Add tub version compat testing
# TODO: Add support to all repos under 0.7

main: help

# Tub protocol version that modules must explicitly support
TUB_PROTOCOL := 5

# Define absolute Root and Tub directories
DIR_MAKEFILE := ${realpath .}
DIR_TUB := $(DIR_MAKEFILE)/tub
DIR_ROOT := ${abspath ${DIR_TUB}/../}

# Tub can run in Rooted and Isolated modes
# 	Rooted - flat unit structure. Used for development
# 	Isolated - modules treated as dependencies, installed in sub-folder. Used in CI pipelines
TUB_MODE := Rooted

# Define directory to resolve /src and /build against
DIR_TUB_ROOT := $(DIR_ROOT)

ifneq ($(shell test -e $(DIR_TUB_ROOT)/tubroot && echo yes),yes)
DIR_TUB_ROOT := $(DIR_MAKEFILE)/tub

TUB_MODE := Isolated
TUB_MODE_ISOLATED := 1
endif

# Inlclude local setup
-include $(DIR_ROOT)/local.mk

# Include supporting Tub functionality
include $(DIR_TUB)/common/__root.mk
include $(DIR_TUB)/meta/__root.mk
include $(DIR_TUB)/compilation/__root.mk

.SECONDARY: