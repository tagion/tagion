# Add bin support
# Add unit test run support
# Test in isolated mode
# Test auto adding dependencies (ensure correct branching as well)
# Add revision
# Add tub version compat testing

# Variable that allows to skip duplicate ${eval include ...}
UNITS_DEFINED :=

# Variables to resolve dependencies and define required targets
UNIT_PREFIX_DIR_LIB := lib-
UNIT_PREFIX_DIR_BIN := bin-
UNIT_PREFIX_DIR_WRAP := wrap-
UNIT_PREFIX_DIR_LIB_TARGET := libtagion
UNIT_PREFIX_DIR_BIN_TARGET := tagion
UNIT_PREFIX_DIR_WRAP_TARGET := wrap-

include $(DIR_TUB)/targets/o.mk
include $(DIR_TUB)/targets/lib.mk

# 
# Target shortcuts
# 
tagion%: $(DIR_BUILD)/bins/tagion%
	@

libtagion%.o: $(DIR_BUILD_O)/libtagion%.o
	@

libtagion%.a: $(DIR_BUILD)/libs/libtagion%.a
	@

libtagion%: libtagion%.a
	@

testall-libtagion%: $(DIR_BUILD)/bins/testall-libtagion%
	@

testscope-libtagion%: $(DIR_BUILD)/bins/testscope-libtagion%
	@

# 
# Interface for context.mk files in Tagion units
# 
# Unit declaration
define unit.lib
${eval ${call _unit.lib, $1}}
endef

define unit.bin
${eval ${call _unit.lib, $1}}
endef

define unit.wrap
${eval ${call _unit.lib, $1}}
endef

# Unit declaration of dependencies
define unit.dep.lib
${eval ${call _unit.dep.lib, $1}}
endef

define unit.dep.wrap
${eval ${call _unit.dep.lib, $1}}
endef

# Unit declaration ending
define unit.end
${eval ${call _unit.end.safe}}
endef

# 
# Implementation
# 
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
endef

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

# Unit declaration of dependencies
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

${eval UNIT_DEPS += ${strip $1}}
endef

# Unit declaration ending
# Will not execute twice (need in rare cases with circular dependencies):
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

# 
# Helpers
# 
define log.archive.details
${call log.header, ${strip $1}}
${call log.kvp, Including}
${call log.lines, $(_ARCHIVES)}
${call log.space}
endef

# 
# Including contexts and defining targets
# 
define include.lib
${call debug, ----- [include.lib] [${strip $1}]}

${call unit.vars.reset, ${strip $1}}

${eval UNIT_MAIN_TEST_ALL := ${if ${findstring testall-, ${strip $1}}, 1,}}
${eval UNIT_MAIN_TEST_SCOPE := ${if ${findstring testscope-, ${strip $1}}, 1,}}
${eval UNIT_MAIN_TEST := $(UNIT_MAIN_TEST_ALL)$(UNIT_MAIN_TEST_SCOPE)}

${eval UNIT_MAIN_TARGET := ${strip $1}}
${eval UNIT_MAIN_DIR := ${strip $1}}
${eval UNIT_MAIN_DIR := ${subst testscope-, , $(UNIT_MAIN_DIR)}}
${eval UNIT_MAIN_DIR := ${subst testall-, , $(UNIT_MAIN_DIR)}}
${eval UNIT_MAIN_DIR := ${subst libtagion, lib-, $(UNIT_MAIN_DIR)}}

# Debug log test mode for the lib
${call debug, [include.lib] [${strip $1}] UNIT_MAIN_DIR = $(UNIT_MAIN_DIR)}
${if $(UNIT_MAIN_TEST), ${call debug, [include.lib] [${strip $1}] UNIT_MAIN_TEST = $(UNIT_MAIN_TEST)},}
${if $(UNIT_MAIN_TEST_ALL), ${call debug, [include.lib] [${strip $1}] UNIT_MAIN_TEST_ALL = $(UNIT_MAIN_TEST_ALL)},}
${if $(UNIT_MAIN_TEST_SCOPE), ${call debug, [include.lib] [${strip $1}] UNIT_MAIN_TEST_SCOPE = $(UNIT_MAIN_TEST_SCOPE)},}

# Include context to resolve all dependencies and generate .o targets
${eval include $(DIR_SRC)/$(UNIT_MAIN_DIR)/context.mk}

# Generate desired target for the lib
${call _unit.target.lib}
${call _unit.target.lib-testall}
${call _unit.target.lib-testscope}
endef

define include.bin
${call debug, including bin is not yet supported}
endef

define include.wrap
${call debug, including wrap is not yet supported}
endef

# 
# Including targets
# 
${eval ${call gen.reset}}

COMPILE_UNIT_PREFIX_TARGETS := ${filter libtagion% tagion% testscope-libtagion% testall-libtagion% wrap-%, $(MAKECMDGOALS)}
ifdef COMPILE_UNIT_PREFIX_TARGETS
COMPILE_UNIT_LIB_TARGETS := ${filter libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_LIB_TARGETS += ${filter testall-libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_LIB_TARGETS += ${filter testscope-libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}

COMPILE_UNIT_BIN_TARGETS := ${filter tagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out testall-libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out testscope-libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}

COMPILE_UNIT_WRAP_TARGETS := ${filter wrap-%, $(COMPILE_UNIT_PREFIX_TARGETS)}

${call debug, [compile.target.defined] lib: $(COMPILE_UNIT_LIB_TARGETS)}
${call debug, [compile.target.defined] bin: $(COMPILE_UNIT_BIN_TARGETS)}
${call debug, [compile.target.defined] wrap: $(COMPILE_UNIT_WRAP_TARGETS)}

${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_LIB_TARGETS), ${eval ${call include.lib, $(COMPILE_UNIT_PREFIX_TARGET)}}}
${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_BIN_TARGETS), ${eval ${call include.bin, $(COMPILE_UNIT_PREFIX_TARGET)}}}
${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_WRAP_TARGETS), ${eval ${call include.wrap, $(COMPILE_UNIT_PREFIX_TARGET)}}}

${call gen.include}
endif
