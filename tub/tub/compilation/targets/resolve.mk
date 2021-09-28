# Declaration start
define _unit.lib
${call debug, ----- [_unit.lib] [${strip $1}]}
${call unit.vars.reset, ${strip $1}}

${eval UNIT_PREFIX_DIR := $(UNIT_PREFIX_DIR_LIB)}
${eval UNIT_PREFIX_TARGET := $(UNIT_PREFIX_DIR_LIB_TARGET)}

${eval UNIT := ${strip $1}}
${eval UNIT_DIR := $(UNIT_PREFIX_DIR)$(UNIT)}
${eval UNIT_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)}
endef

define _unit.bin
${call debug, ----- [_unit.bin] [${strip $1}]}
${call unit.vars.reset, ${strip $1}}

${eval UNIT_PREFIX_DIR := $(UNIT_PREFIX_DIR_BIN)}
${eval UNIT_PREFIX_TARGET := $(UNIT_PREFIX_DIR_BIN_TARGET)}

${eval UNIT := ${strip $1}}
${eval UNIT_DIR := $(UNIT_PREFIX_DIR)$(UNIT)}
${eval UNIT_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)}
endef

# Declaration of dependencies
define _unit.dep.lib
${call debug, ----- [_unit.dep.lib] [${strip $1}]}

# Add to current unit definition dependencies if not added yet
${if ${findstring ${strip $1}, $(UNIT_DEPS)},,${eval UNIT_DEPS += ${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB)${strip $1}, $(UNIT_DEPS_DIR)},,${eval UNIT_DEPS_DIR += $(UNIT_PREFIX_DIR_LIB)${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}, $(UNIT_DEPS_TARGET)},,${eval UNIT_DEPS_TARGET += $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}}}

# Add to compile target dependencies if not added yet
${if ${findstring ${strip $1}, $(UNIT_MAIN_DEPS)},,${eval UNIT_MAIN_DEPS += ${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB)${strip $1}, $(UNIT_MAIN_DEPS_DIR)},,${eval UNIT_MAIN_DEPS_DIR += $(UNIT_PREFIX_DIR_LIB)${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}, $(UNIT_MAIN_DEPS_TARGET)},,${eval UNIT_MAIN_DEPS_TARGET += $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}}}
endef

define _unit.dep.wrap
${call debug, [_unit.dep.wrap] [${strip $1}]}

${call unit.dep.wrap-${strip $1}}
endef

# Unit declaration end
# Safe wrapper ensures not to execute twice
# (need in rare cases with circular dependencies):
define _unit.end.safe
${call debug, ----- [_unit.end.safe] [$(UNIT_DIR)]}
${eval UNIT_DEFINED_BLOCKER := ${findstring $(UNIT_DIR), $(UNITS_DEFINED)}}
${if $(UNIT_DEFINED_BLOCKER), , ${eval ${call _unit.end}}}
endef

define _unit.end
${call debug, ----- [_unit.end] [$(UNIT_DIR)]}

${eval UNITS_DEFINED += $(UNIT_DIR)}

${call debug, [_unit.end] [$(UNIT_DIR)] defined: $(UNITS_DEFINED)}
${call debug, [_unit.end] [$(UNIT_DIR)] dependencies: $(UNIT_DEPS_TARGET)}

# Define .o targets
${call _unit.target.o}
${call _unit.target.o-test}

# Exclude dependencies that were already included from UNIT_DEPS_DIR:
${foreach UNIT_DEFINED, $(UNITS_DEFINED), ${eval UNIT_DEPS_DIR := ${patsubst $(UNIT_DEFINED),,$(UNIT_DEPS_DIR)}}}
# Include dependencies:
${foreach UNIT_DEP_DIR, $(UNIT_DEPS_DIR), ${eval include $(DIR_SRC)/$(UNIT_DEP_DIR)/context.mk}}
endef