# TODO: Finish macros for target
# Add wrapper support
# Add bin support
# Add unit test run support
# Test in isolated mode
# Test auto adding dependencies (ensure correct branching as well)
# Add revision

DIR_UNITMK := $(DIR_BUILD_TEMP)/mk
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



# Unit declaration ending
define unit.end
# Will not execute twice (need in rare cases with circular dependencies):
${eval UNIT_DEFINED_BLOCK := ${findstring $(UNIT_PREFIXED), $(UNITS_DEFINED)}}
${if $(UNIT_DEFINED_BLOCK), , ${eval ${call _unit.end}}}
endef

define _unit.end
${call debug, unit.end $(UNIT)}

${call debug, -! $(UNIT)/$(UNIT_PREFIXED)/$(UNIT_PREFIXED_TARGET) defined, deps: $(UNIT_DEPS)}

${shell mkdir -p $(DIR_UNITMK)}

${eval UNITS_DEFINED += $(UNIT_PREFIXED)}
${eval UNIT_IS_COMPILE_TARGET := ${findstring $(UNIT_PREFIXED), $(COMPILE_UNIT_TARGETS)}}

${eval _INCFLAGS) := -I$(DIR_SRC)/$(UNIT_PREFIXED)}
${eval _INCFLAGS) += ${foreach UNIT_DEP_PREFIXED, $(UNIT_DEPS_PREFIXED), -I$(DIR_SRC)/$(UNIT_DEP_PREFIXED)}}

# Define obj targets
${if $(UNIT_IS_COMPILE_TARGET), ${call _unit.target.compile},${call _unit.target.obj}}

# Remove dependencies that were already included:
${foreach UNIT_DEFINED, $(UNITS_DEFINED), ${eval UNIT_DEPS_PREFIXED := ${patsubst $(UNIT_DEFINED),,$(UNIT_DEPS_PREFIXED)}}}
# Include new dependencies:
${foreach UNIT_DEP_PREFIXED, $(UNIT_DEPS_PREFIXED), ${eval include $(DIR_SRC)/$(UNIT_DEP_PREFIXED)/context.mk}}
endef

# 
# Helpers
# 
define _unit.target.compile
${call debug, making make $(UNIT) $(UNIT_PREFIXED_TARGET) $(UNIT_DEPS)}
${shell echo "$(UNIT_PREFIXED_TARGET): $(DIR_BUILD)/o/$(UNIT_PREFIXED_TARGET).o" > $(DIR_UNITMK)/$(UNIT_PREFIXED_TARGET).mk}
${shell echo "\t@echo hello $(UNIT_PREFIXED_TARGET) $(UNIT)" >> $(DIR_UNITMK)/$(UNIT_PREFIXED_TARGET).mk}

${eval include $(DIR_UNITMK)/$(UNIT_PREFIXED_TARGET).mk}
endef

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

define unit.vars.reset
UNIT :=
UNIT_PREFIX :=
UNIT_PREFIX_TARGET :=
UNIT_PREFIXED :=
UNIT_PREFIXED_TARGET :=
UNIT_DEPS :=
UNIT_DEPS_PREFIXED :=
UNIT_DEPS_PREFIXED_TARGETS :=
endef

define unit.target.o
$(DIR_BUILD_O)/$(UNIT_TARGET).o:
	@echo hello world $$(@) Unit: $(UNIT), my deps are $(UNIT_DEPS_PREFIXED_TARGETS)

$(UNIT_TARGET): $(DIR_BUILD)/o/$(UNIT_TARGET).o
	@
endef

define parse.unit.deps
${eval UNIT_DEPS_PREFIXED := $(DEP)}
${eval UNIT_DEPS := ${subst lib-, , $(UNIT_DEPS_PREFIXED)}}
${eval UNIT_DEPS_PREFIXED_TARGETS := ${subst lib-, libtagion, $(DEP)}}

${call debug, DEP: $(DEP)}
${call debug, UNIT_DEPS: $(UNIT_DEPS)}
${call debug, UNIT_DEPS_PREFIXED: $(UNIT_DEPS_PREFIXED)}
${call debug, UNIT_DEPS_PREFIXED_TARGETS: $(UNIT_DEPS_PREFIXED_TARGETS)}
endef

define parse.unit.target
${eval UNIT_TEST_ALL := ${findstring testall-, $(UNIT_ARG)}}
${eval UNIT_TEST_SCOPE := ${findstring testscope-, $(UNIT_ARG)}}

${eval UNIT_TARGET := $(UNIT_ARG)}}
${eval UNIT_TARGET := ${subst testsall-, , $(UNIT_TARGET)}}
${eval UNIT_TARGET := ${subst testscope-, , $(UNIT_TARGET)}}
endef

define include.lib
${eval ${call unit.vars.reset}}
${eval UNIT_ARG := ${subst lib-,,${strip $1}}}
${call parse.unit.target}

${eval UNIT := ${subst libtagion, , $(UNIT_TARGET)}}
${eval UNIT_DIR := $(UNIT_PREFIX_LIB)$(UNIT)}

${call debug, including $(UNIT_DIR) ($(UNIT_TARGET))...}
${call debug, TEST: $(UNIT_TEST_ALL) $(UNIT_TEST_SCOPE)}
${eval include $(DIR_SRC)/$(UNIT_DIR)/context.mk}
${call parse.unit.deps}

${call unit.target.o}
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
COMPILE_UNIT_TARGETS := ${filter libtagion% tagion% testscope-libtagion% testall-libtagion%, $(MAKECMDGOALS)}
ifdef COMPILE_UNIT_TARGETS
COMPILE_UNIT_LIB_TARGETS := ${filter libtagion%, $(COMPILE_UNIT_TARGETS)}
COMPILE_UNIT_LIB_TARGETS += ${filter testall-libtagion%, $(COMPILE_UNIT_TARGETS)}
COMPILE_UNIT_LIB_TARGETS += ${filter testscope-libtagion%, $(COMPILE_UNIT_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter tagion%, $(COMPILE_UNIT_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out testall-libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out testscope-libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_WRAP_TARGETS := ${filter wrap-%, $(COMPILE_UNIT_TARGETS)}

${foreach COMPILE_UNIT_TARGET, $(COMPILE_UNIT_LIB_TARGETS), ${call include.lib, $(COMPILE_UNIT_TARGET)}}
${foreach COMPILE_UNIT_TARGET, $(COMPILE_UNIT_BIN_TARGETS), ${call include.bin, $(COMPILE_UNIT_TARGET)}}
${foreach COMPILE_UNIT_TARGET, $(COMPILE_UNIT_WRAP_TARGETS), ${call include.wrap, $(COMPILE_UNIT_TARGET)}}
endif
