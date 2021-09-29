define include.lib
${call debug.open, INCLUDE_LIB ${strip $1}}

${call unit.vars.reset, ${strip $1}}

${eval UNIT_MAIN_TARGET := ${strip $1}}
${eval UNIT_MAIN_DIR := ${strip $1}}
${eval UNIT_MAIN_DIR := ${subst testscope-, , $(UNIT_MAIN_DIR)}}
${eval UNIT_MAIN_DIR := ${subst testall-, , $(UNIT_MAIN_DIR)}}
${eval UNIT_MAIN_DIR := ${subst libtagion, lib-, $(UNIT_MAIN_DIR)}}

# Debug log test mode for the lib
${call debug, Directory name: $(UNIT_MAIN_DIR)}

# Include context to resolve all dependencies and generate .o targets
${eval include $(DIR_SRC)/$(UNIT_MAIN_DIR)/context.mk}

# Generate desired target for the lib
${call _unit.target.lib}
${call _unit.target.lib-testall}
${call _unit.target.lib-testscope}

${call debug.close, INCLUDE_LIB ${strip $1}}
${call debug.space}
endef

define include.bin
${call debug.open, INCLUDE_BIN ${strip $1}}

${call unit.vars.reset, ${strip $1}}

${eval UNIT_MAIN_TARGET := ${strip $1}}
${eval UNIT_MAIN_DIR := ${strip $1}}
${eval UNIT_MAIN_DIR := ${subst tagion, bin-, $(UNIT_MAIN_DIR)}}

# Debug log test mode for the bin
${call debug, Directory name: $(UNIT_MAIN_DIR)}

# Include context to resolve all dependencies and generate .o targets
${eval include $(DIR_SRC)/$(UNIT_MAIN_DIR)/context.mk}

# Generate desired target for the bin
${call _unit.target.bin}

${call debug.close, INCLUDE_BIN ${strip $1}}
${call debug.space}
endef