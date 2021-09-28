# Variable that allows to skip duplicate ${eval include ...}
UNITS_DEFINED :=

# Variables to resolve dependencies and define required targets
UNIT_PREFIX_DIR_LIB := lib-
UNIT_PREFIX_DIR_BIN := bin-
UNIT_PREFIX_DIR_WRAP := wrap-
UNIT_PREFIX_DIR_LIB_TARGET := libtagion
UNIT_PREFIX_DIR_BIN_TARGET := tagion
UNIT_PREFIX_DIR_WRAP_TARGET := wrap-

# Finding all libs to define 'import paths' for compiler
LIB_DIRS_WORKSPACE := ${shell ls -d $(DIR_SRC)/*/ | grep -v wrap- | grep -v bin-}
LIB_DIRS_WORKSPACE := $(patsubst %/, %, $(LIB_DIRS_WORKSPACE))

define unit.vars.reset
${call debug, ----- [unit.vars.reset] [${strip $1}]}

${eval UNIT_PREFIX_DIR :=}
${eval UNIT_PREFIX_TARGET :=}

${eval UNIT :=}
${eval UNIT_DIR :=}
${eval UNIT_TARGET :=}
${eval UNIT_DEPS :=}
${eval UNIT_DEPS_DIR :=}
${eval UNIT_DEPS_TARGET :=}
${eval UNIT_WRAPS_TARGETS :=}
endef

# The flow of target generation:
# 	1. goals.mk - parse make arguments to define targets
# 	2. include.mk - initiate target generation process
# 	3. resolve.mk - resolve dependencies of target unit
# 
# For each target found in 1, do 2 -> 3;

include $(DIR_TUB)/compilation/targets/list.mk
include $(DIR_TUB)/compilation/targets/include.mk
include $(DIR_TUB)/compilation/targets/resolve.mk

include $(DIR_TUB)/compilation/targets/interface.mk

include $(DIR_TUB)/compilation/targets/goals.mk