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

${eval _INCFLAGS := -I$(DIR_SRC)/$(UNIT_DIR)}
${eval _INCFLAGS += ${foreach UNIT_DEP_DIR, $(UNIT_DEPS_DIR), -I$(DIR_SRC)/$(UNIT_DEP_DIR)}}
${eval _INCFLAGS += ${addprefix -I$(DIR_SRC)/, $(UNIT_DEPS_DIR)}}
${eval _INFILES := ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.d'}}
${eval _INFILES += ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.di'}}

$(UNIT_TARGET).o: $(DIR_BUILD_O)/$(UNIT_TARGET).o
	@

$(DIR_BUILD_O)/$(UNIT_TARGET).o: | ways $(_INFILES)
	${eval _TARGET := $(DIR_BUILD_O)/$(UNIT_TARGET).o}

	${eval _DCFLAGS := $(DCFLAGS)}
	${eval _DCFLAGS += -c}
	${eval _DCFLAGS += -of$(_TARGET)}
	
	${call log.header, $$(@F)}
	${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}
	${call log.separator}
	${call log.kvp, DC, $(DC)}
	${call log.kvp, DCFLAGS, $(_DCFLAGS)}
	${call log.kvp, INCFLAGS}
	${call log.lines, $(_INCFLAGS)}
	${call log.kvp, INFILES}
	${call log.lines, $(_INFILES)}
	${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}
	${call log.space}

	${eval _LDCFLAGS := $(LDCFLAGS)}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(_TARGET)}
endef

define _unit.target.compile
${call debug, [_unit.target.compile] [$(UNIT_TARGET_INITIAL)]}

${eval _TARGET := $(DIR_BUILD)/bins/$(UNIT_TARGET_INITIAL)}

${eval _INCFLAGS := -I$(DIR_SRC)/$(UNIT_DIR_INITIAL)}
${eval _INCFLAGS += ${addprefix -I$(DIR_SRC)/, $(UNIT_DEPS_DIR)}}
${call debug, ---- ${UNIT} - $(UNIT_DEPS_DIR)}

# Need to cache deps for initial target?

${eval _INFILES := ${shell find $(DIR_SRC)/$(UNIT_DIR_INITIAL) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.d'}}
${eval _INFILES += ${shell find $(DIR_SRC)/$(UNIT_DIR_INITIAL) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.di'}}
${eval _INFILES += ${addprefix $(DIR_BUILD_O)/, $(UNIT_DEPS_TARGET:=.o)}}

${eval _DCFLAGS := $(DCFLAGS)}
${if $(UNIT_TEST), ${eval _DCFLAGS += -unittest}}
${if $(UNIT_TEST), ${eval _DCFLAGS += -main}}
${if $(UNIT_TEST), ${eval _DCFLAGS += -g}}
${eval _DCFLAGS += -of$(_TARGET)}
${eval _LDCFLAGS := $(LDCFLAGS)}

$(UNIT_TARGET_INITIAL): ${_INFILES}
	${call log.header, $$(@F)}
	${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}
	${call log.separator}
	${call log.kvp, DC, $(DC)}
	${call log.kvp, DCFLAGS, $(_DCFLAGS)}
	${call log.kvp, INCFLAGS}
	${call log.lines, $(_INCFLAGS)}
	${call log.kvp, INFILES}
	${call log.lines, $(_INFILES)}
	${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}
	${call log.space}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(_TARGET)}
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

${eval UNIT_PREFIX_DIR := $(UNIT_PREFIX_DIR_LIB)}
${eval UNIT_PREFIX_TARGET := $(UNIT_PREFIX_DIR_LIB_TARGET)}

${eval UNIT := ${strip $1}}
${eval UNIT_DIR := $(UNIT_PREFIX_DIR)$(UNIT)}
${eval UNIT_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)}
endef

define _unit.bin
${call debug, [_unit.bin] [${strip $1}]}

${eval UNIT_PREFIX_DIR := $(UNIT_PREFIX_DIR_BIN)}
${eval UNIT_PREFIX_TARGET := $(UNIT_PREFIX_DIR_BIN_TARGET)}

${eval UNIT := ${strip $1}}
${eval UNIT_DIR := $(UNIT_PREFIX_DIR)$(UNIT)}
${eval UNIT_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)}
endef

# Unit declaration of dependencies
define _unit.dep.lib
${call debug, [_unit.dep.lib] [${strip $1}]}

${eval UNIT_DEPS += ${strip $1}}
${if ${findstring ${strip $1}, $(UNIT_DEPS)},,${eval UNIT_DEPS += ${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB)${strip $1}, $(UNIT_DEPS_DIR)},,${eval UNIT_DEPS_DIR += $(UNIT_PREFIX_DIR_LIB)${strip $1}}}
${if ${findstring $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}, $(UNIT_DEPS_TARGET)},,${eval UNIT_DEPS_TARGET += $(UNIT_PREFIX_DIR_LIB_TARGET)${strip $1}}}
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

# Define obj targets
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
${call log.lines, $(_INFILES)}
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

${eval UNIT_TARGET_INITIAL := ${strip $1}}
${eval UNIT_DIR_INITIAL := ${strip $1}}
${eval UNIT_DIR_INITIAL := ${subst testscope-, , $(UNIT_DIR_INITIAL)}}
${eval UNIT_DIR_INITIAL := ${subst testsall-, , $(UNIT_DIR_INITIAL)}}
${eval UNIT_DIR_INITIAL := ${subst libtagion, lib-, $(UNIT_DIR_INITIAL)}}

${call debug, [include.lib] [${strip $1}] UNIT_DIR_INITIAL = $(UNIT_DIR_INITIAL)}
${if $(UNIT_TEST), ${call debug, [include.lib] [${strip $1}] UNIT_TEST},}
${if $(UNIT_TEST_ALL), ${call debug, [include.lib] [${strip $1}] UNIT_TEST_ALL},}
${if $(UNIT_TEST_SCOPE), ${call debug, [include.lib] [${strip $1}] UNIT_TEST_SCOPE},}

${eval stash := $(UNIT_DIR_INITIAL)}

${eval include $(DIR_SRC)/$(UNIT_DIR_INITIAL)/context.mk}

${call _unit.target.compile}
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
# ${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_BIN_TARGETS), ${eval ${call include.bin, $(COMPILE_UNIT_PREFIX_TARGET)}}}
# ${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_WRAP_TARGETS), ${eval ${call include.wrap, $(COMPILE_UNIT_PREFIX_TARGET)}}}
endif
