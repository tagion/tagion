# TODO: Finish macros for target
# Add wrapper support
# Add bin support
# Add unit test run support
# Test in isolated mode
# Test auto adding dependencies (ensure correct branching as well)
# Add revision

# Variable that allows to skip duplicate ${eval include ...}
UNITS_DEFINED :=

# Variables to resolve dependencies and define required targets
UNIT_PREFIX_DIR_LIB := lib-
UNIT_PREFIX_DIR_BIN := bin-
UNIT_PREFIX_DIR_WRAP := wrap-
UNIT_PREFIX_DIR_LIB_TARGET := libtagion
UNIT_PREFIX_DIR_BIN_TARGET := tagion
UNIT_PREFIX_DIR_WRAP_TARGET := wrap-

# 
# Target shortcuts
# 
tagion%: $(DIR_BUILD)/bins/tagion%
	@

libtagion%.o: | libtagion%.ctx $(DIR_BUILD_O)/libtagion%.o
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
# Target declaration
# 
define _unit.target.o
${call debug, [_unit.target.o] [$(UNIT_TARGET)]}

${eval _TARGET := $(DIR_BUILD_O)/$(UNIT_TARGET).o}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _INCFLAGS := -I$(DIR_SRC)/$(UNIT_DIR)}
${eval _INCFLAGS += ${addprefix -I$(DIR_SRC)/, $(UNIT_DEPS_DIR)}}

${eval _DFILES := ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.d'}}
${eval _DFILES += ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.di'}}
${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _INFILES := $(_DFILES)}

${call gen.line, $(_TARGET): | ways $(_DFILES)}
${call gen.linetab, \$${call log.header, $(UNIT_TARGET)}}
${call gen.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.linetab, \$${call log.space}}
${call gen.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)}
${call gen.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.linetab, \$${call log.space}}
${call gen.space}
endef

define _unit.target.lib
${call debug, [_unit.target.lib] [$(UNIT_COMPILE_TARGET)]}

${if $(UNIT_TEST), ${eval _TARGET := $(DIR_BUILD)/bins/$(UNIT_COMPILE_TARGET)},${eval _TARGET := $(DIR_BUILD)/libs/$(UNIT_COMPILE_TARGET).a}}

${eval _DCFLAGS := $(DCFLAGS)}

${if $(UNIT_TEST), ${eval _DCFLAGS += -unittest}}
${if $(UNIT_TEST), ${eval _DCFLAGS += -main}}
${if $(UNIT_TEST), ${eval _DCFLAGS += -g}}
${if $(UNIT_TEST),,${eval _DCFLAGS += -c}}

${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _INCFLAGS := -I$(DIR_SRC)/$(UNIT_COMPILE_DIR)}
${eval _INCFLAGS += ${addprefix -I$(DIR_SRC)/, $(UNIT_COMPILE_DEPS_DIR)}}

${eval _DFILES := ${shell find $(DIR_SRC)/$(UNIT_COMPILE_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.d'}}
${eval _DFILES += ${shell find $(DIR_SRC)/$(UNIT_COMPILE_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.di'}}

${eval _OFILES := ${addprefix $(DIR_BUILD_O)/, $(UNIT_COMPILE_DEPS_TARGET:=.o)}}

${eval _INFILES := $(_DFILES)}
${eval _INFILES += $(_OFILES)}

${call gen.line, $(_TARGET): $(_OFILES) | ways $(_DFILES)}
${call gen.linetab, \$${call log.header, $(UNIT_COMPILE_TARGET)}}
${call gen.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.linetab, \$${call log.space}}
${call gen.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)}
${call gen.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.linetab, \$${call log.space}}
${call gen.space}
endef

# 
# Implementation
# 
define unit.vars.reset
${call debug, [unit.vars.reset]}

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
${call debug, [_unit.lib] [${strip $1}]}
${call unit.vars.reset}

${eval UNIT_PREFIX_DIR := $(UNIT_PREFIX_DIR_LIB)}
${eval UNIT_PREFIX_TARGET := $(UNIT_PREFIX_DIR_LIB_TARGET)}

${eval UNIT := ${strip $1}}
${eval UNIT_DIR := $(UNIT_PREFIX_DIR)$(UNIT)}
${eval UNIT_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)}
endef

define _unit.bin
${call debug, [_unit.bin] [${strip $1}]}
${call unit.vars.reset}

${eval UNIT_PREFIX_DIR := $(UNIT_PREFIX_DIR_BIN)}
${eval UNIT_PREFIX_TARGET := $(UNIT_PREFIX_DIR_BIN_TARGET)}

${eval UNIT := ${strip $1}}
${eval UNIT_DIR := $(UNIT_PREFIX_DIR)$(UNIT)}
${eval UNIT_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)}
endef

# Unit declaration of dependencies
define _unit.dep.lib
${call debug, [_unit.dep.lib] [${strip $1}]}

${if ${findstring ${strip $1}, $(UNIT_DEPS)},,${eval UNIT_DEPS += ${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB)${strip $1}, $(UNIT_DEPS_DIR)},,${eval UNIT_DEPS_DIR += $(UNIT_PREFIX_DIR_LIB)${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}, $(UNIT_DEPS_TARGET)},,${eval UNIT_DEPS_TARGET += $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}}}

${if ${findstring ${strip $1}, $(UNIT_COMPILE_DEPS)},,${eval UNIT_COMPILE_DEPS += ${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB)${strip $1}, $(UNIT_COMPILE_DEPS_DIR)},,${eval UNIT_COMPILE_DEPS_DIR += $(UNIT_PREFIX_DIR_LIB)${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}, $(UNIT_COMPILE_DEPS_TARGET)},,${eval UNIT_COMPILE_DEPS_TARGET += $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}}}
endef

define _unit.dep.wrap
${call debug, [_unit.dep.wrap] [${strip $1}]}

${eval UNIT_DEPS += ${strip $1}}
endef

# Unit declaration ending
# Will not execute twice (need in rare cases with circular dependencies):
define _unit.end.safe
${call debug, [_unit.end.safe] [$(UNIT_DIR)]}
${eval UNIT_DEFINED_BLOCKER := ${findstring $(UNIT_DIR), $(UNITS_DEFINED)}}
${if $(UNIT_DEFINED_BLOCKER), , ${eval ${call _unit.end}}}
endef

define _unit.end
${call debug, [_unit.end] [$(UNIT_DIR)]}

${eval UNITS_DEFINED += $(UNIT_DIR)}
${call debug, [_unit.end] [$(UNIT_DIR)] defined $(UNITS_DEFINED)}
${call debug, [_unit.end] [$(UNIT_DIR)] depends $(UNIT_DEPS_TARGET)}

# Define .o targets
${call _unit.target.o}

# Remove dependencies that were already included:
${foreach UNIT_DEFINED, $(UNITS_DEFINED), ${eval UNIT_DEPS_DIR := ${patsubst $(UNIT_DEFINED),,$(UNIT_DEPS_DIR)}}}
# Include new dependencies:
${foreach UNIT_DEP_DIR, $(UNIT_DEPS_DIR), ${eval include $(DIR_SRC)/$(UNIT_DEP_DIR)/context.mk}}
endef



# 
# Helpers
# 
define find.files
${shell find ${strip $1} -not -path "$(SOURCE_FIND_EXCLUDE)" -name '${strip $2}'}
endef

define execute.ifnot.parallel
${if $${shell [[ "$$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1},,$1}
endef

define execute.if.parallel
${if $${shell [[ "$$(MAKEFLAGS)" =~ "jobserver-fds" ]] && echo 1},$1,}
endef

define log.compile.details
${call log.header, ${strip $1}}
${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}
${call log.separator}
${call log.kvp, DC, $(DC)}
${call log.kvp, DCFLAGS, $(_DCFLAGS)}
${call log.kvp, INCFLAGS}
${call log.lines, $(_INCFLAGS)}
${call log.kvp, INFILES}
${call log.lines, $(_DFILES)}
${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}
${call log.space}
endef

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
${call debug, [include.lib] [${strip $1}] ------>}

${call unit.vars.reset}

${eval UNIT_TEST_ALL := ${if ${findstring testall-, ${strip $1}}, 1,}}
${eval UNIT_TEST_SCOPE := ${if ${findstring testscope-, ${strip $1}}, 1,}}
${eval UNIT_TEST := $(UNIT_TEST_ALL)$(UNIT_TEST_SCOPE)}

${eval UNIT_COMPILE_TARGET := ${strip $1}}
${eval UNIT_COMPILE_DIR := ${strip $1}}
${eval UNIT_COMPILE_DIR := ${subst testscope-, , $(UNIT_COMPILE_DIR)}}
${eval UNIT_COMPILE_DIR := ${subst testsall-, , $(UNIT_COMPILE_DIR)}}
${eval UNIT_COMPILE_DIR := ${subst libtagion, lib-, $(UNIT_COMPILE_DIR)}}

${call debug, [include.lib] [${strip $1}] UNIT_COMPILE_DIR = $(UNIT_COMPILE_DIR)}
${if $(UNIT_TEST), ${call debug, [include.lib] [${strip $1}] UNIT_TEST},}
${if $(UNIT_TEST_ALL), ${call debug, [include.lib] [${strip $1}] UNIT_TEST_ALL},}
${if $(UNIT_TEST_SCOPE), ${call debug, [include.lib] [${strip $1}] UNIT_TEST_SCOPE},}

${eval stash := $(UNIT_COMPILE_DIR)}

${eval include $(DIR_SRC)/$(UNIT_COMPILE_DIR)/context.mk}

${call _unit.target.lib}
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

${call debug, [target.defined] [lib] $(COMPILE_UNIT_LIB_TARGETS)}
${call debug, [target.defined] [bin] $(COMPILE_UNIT_BIN_TARGETS)}
${call debug, [target.defined] [wrap] $(COMPILE_UNIT_WRAP_TARGETS)}

${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_LIB_TARGETS), ${eval ${call include.lib, $(COMPILE_UNIT_PREFIX_TARGET)}}}
${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_BIN_TARGETS), ${eval ${call include.bin, $(COMPILE_UNIT_PREFIX_TARGET)}}}
${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_WRAP_TARGETS), ${eval ${call include.wrap, $(COMPILE_UNIT_PREFIX_TARGET)}}}

${call gen.include}
endif
