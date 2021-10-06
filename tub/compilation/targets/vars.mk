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
${call debug, Resetting UNIT variables}

${eval UNIT_PREFIX_DIR :=}
${eval UNIT_PREFIX_TARGET :=}

${eval UNIT :=}
${eval UNIT_DIR :=}
${eval UNIT_TARGET :=}
${eval UNIT_DEPS :=}
${eval UNIT_DEPS_DIR :=}
${eval UNIT_DEPS_TARGET :=}

${eval UNIT_DEPS_MACROS :=}

${eval UNIT_WRAPS_TARGETS :=}
${eval UNIT_WRAPS_INFILES :=}
${eval UNIT_WRAPS_INCFLAGS :=}
${eval UNIT_WRAPS_LINKFILES :=}
endef
