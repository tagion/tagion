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
${call debug, ----- [include.bin] [${strip $1}]}

${call unit.vars.reset, ${strip $1}}

${eval UNIT_MAIN_TARGET := ${strip $1}}
${eval UNIT_MAIN_DIR := ${strip $1}}
${eval UNIT_MAIN_DIR := ${subst tagion, bin-, $(UNIT_MAIN_DIR)}}

# Debug log test mode for the bin
${call debug, [include.bin] [${strip $1}] UNIT_MAIN_DIR = $(UNIT_MAIN_DIR)}

# Include context to resolve all dependencies and generate .o targets
${eval include $(DIR_SRC)/$(UNIT_MAIN_DIR)/context.mk}

# Generate desired target for the bin
${call _unit.target.bin}
endef