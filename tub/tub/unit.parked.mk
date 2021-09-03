# TODO: Finish macros for target
# Add wrapper support
# Add bin support
# Add unit test run support
# Test in isolated mode
# Test auto adding dependencies (ensure correct branching as well)
# Add revision

DIR_UNITMK := $(DIR_BUILD)/makes
WAYS += $(DIR_UNITMK)/.way

# Variable that allows to skip duplicate ${eval include ...}
UNITS_DEFINED := _

# Variables to resolve dependencies and define required targets
UNIT_PREFIX_LIB := lib-
UNIT_PREFIX_BIN := bin-
UNIT_PREFIX_WRAP := wrap-
UNIT_PREFIX_LIB_TARGET := libtagion
UNIT_PREFIX_BIN_TARGET := tagion
UNIT_PREFIX_WRAP_TARGET := wrap-

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
define _unit.vars.reset
UNIT :=
UNIT_PREFIX :=
UNIT_PREFIX_TARGET :=
UNIT_DEPS :=
UNIT_DEPS_PREFIXED :=
UNIT_DEPS_PREFIXED_TARGETS :=
endef

define _unit.lib
${info -> start unit lib ${strip $1}, at this point already defined: $(UNITS_DEFINED)}
${call _unit.vars.reset}
UNIT := ${strip $1}
UNIT_PREFIX := $(UNIT_PREFIX_LIB)
UNIT_PREFIX_TARGET := $(UNIT_PREFIX_LIB_TARGET)
UNIT_PREFIXED := $(UNIT_PREFIX)$(UNIT)
UNIT_PREFIXED_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)
endef

define _unit.bin
${info -> start unit bin ${strip $1}, at this point already defined: $(UNITS_DEFINED)}
${call _unit.vars.reset}
UNIT := ${strip $1}
UNIT_PREFIX := $(UNIT_PREFIX_BIN)
UNIT_PREFIX_TARGET := $(UNIT_PREFIX_BIN_TARGET)
UNIT_PREFIXED := $(UNIT_PREFIX)$(UNIT)
UNIT_PREFIXED_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)
endef

define _unit.wrap
${info -> start unit wrap ${strip $1}, at this point already defined: $(UNITS_DEFINED)}
${call _unit.vars.reset}
UNIT := ${strip $1}
UNIT_PREFIX := $(UNIT_PREFIX_WRAP)
UNIT_PREFIX_TARGET := $(UNIT_PREFIX_WRAP_TARGET)
UNIT_PREFIXED := $(UNIT_PREFIX)$(UNIT)
UNIT_PREFIXED_TARGET := $(UNIT_PREFIX_TARGET)$(UNIT)
endef

# Unit declaration of dependencies
define _unit.dep.lib
${info -> add lib ${strip $1} to $(UNIT)}
UNIT_DEPS += ${strip $1}
UNIT_DEPS_PREFIXED += $(UNIT_PREFIX_LIB)${strip $1}
UNIT_DEPS_PREFIXED_TARGETS += $(UNIT_PREFIX_LIB_TARGET)${strip $1}
endef

define _unit.dep.wrap
${info -> add wrap ${strip $1} to $(UNIT)}
UNIT_DEPS += ${strip $1}
UNIT_DEPS_PREFIXED += $(UNIT_PREFIX_WRAP)${strip $1}
UNIT_DEPS_PREFIXED_TARGETS += $(UNIT_PREFIX_WRAP_TARGET)${strip $1}
endef

# Unit declaration ending
define _unit.end.safe
# Will not execute twice (need in rare cases with circular dependencies):
${eval UNIT_DEFINED_BLOCK := ${findstring $(UNIT_PREFIXED), $(UNITS_DEFINED)}}
${if $(UNIT_DEFINED_BLOCK), , ${eval ${call _unit.end}}}
endef

define _unit.target.obj
${shell $(DIR_BUILD)/o/$(UNIT_PREFIXED_TARGET).o: | ways $(UNIT_D_FILES) > $(DIR_UNITMK)/$(UNIT_PREFIXED_TARGET).mk}

$(DIR_BUILD)/o/$(UNIT_PREFIXED_TARGET).o: | ways $(UNIT_D_FILES)
	${eval _INFILES := ${call find.files, ${DIR_SRC}/$(UNIT_PREFIXED), *.d}}

	${eval _TARGET := $(DIR_BUILD)/o/$(UNIT_PREFIXED_TARGET).o}

	${eval _DCFLAGS := $(DCFLAGS)}
	${eval _DCFLAGS += -c}
	${eval _DCFLAGS += -of$(_TARGET)}
	
	$${call log.compile.details}
	${call log.line, --- $$(@) $(_TARGET)}

	${eval _LDCFLAGS := $(LDCFLAGS)}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(_TARGET)}
endef

define _unit.target.compile
$(UNIT_PREFIXED_TARGET): ${addprefix $(DIR_BUILD)/o/, $(UNIT_DEPS_PREFIXED_TARGETS:=.o)} $(UNIT_D_FILES)
	${eval _TARGET := $(DIR_BUILD)/o/$(UNIT_PREFIXED_TARGET).o}
	${call log.line, $(@)}
	${eval _DCFLAGS := $(DCFLAGS)}
	${eval _DCFLAGS += -c}
	${eval _DCFLAGS += -of$(_TARGET)}
	
	$${call log.compile.details}

	${eval _LDCFLAGS := $(LDCFLAGS)}
	$(PRECMD)$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)
	${call log.kvp, Compiled, $(_TARGET)}
endef

define _unit.end
${info -> $(UNIT) defined, deps: $(UNIT_DEPS)}

${eval UNITS_DEFINED += $(UNIT_PREFIXED)}
${eval UNIT_IS_COMPILE_TARGET := ${findstring $(UNIT_PREFIXED), $(COMPILE_UNIT_TARGETS)}}

${eval _INCFLAGS) := -I$(DIR_SRC)/$(UNIT_PREFIXED)}
${eval _INCFLAGS) += ${foreach UNIT_DEP_PREFIXED, $(UNIT_DEPS_PREFIXED), -I$(DIR_SRC)/$(UNIT_DEP_PREFIXED)}}

# Define obj targets
${call _unit.target.obj}

# Define compile targets
# ${if $(UNIT_IS_COMPILE_TARGET), ${eval ${call _unit.target.compile}},}

# Remove dependencies that were already included:
${foreach UNIT_DEFINED, $(UNITS_DEFINED), ${eval UNIT_DEPS_PREFIXED := ${patsubst $(UNIT_DEFINED),,$(UNIT_DEPS_PREFIXED)}}}
# Include new dependencies:
${foreach UNIT_DEP_PREFIXED, $(UNIT_DEPS_PREFIXED), ${eval include $(DIR_SRC)/$(UNIT_DEP_PREFIXED)/context.mk}}
endef



# 
# Helpers
# 
# 
# Compilation
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