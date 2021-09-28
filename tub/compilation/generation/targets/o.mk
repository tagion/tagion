define _unit.target.o
${eval _UNIT_TARGET := $(UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET).o-logs}
${eval _TARGET := $(DIR_BUILD_O)/$(_UNIT_TARGET).o}

${call debug, ------- [_unit.target.o] [$(_UNIT_TARGET)]}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _INCFLAGS := ${addprefix -I, $(LIB_DIRS_WORKSPACE)}}
${eval _INCFLAGS += $(WRAP_INCFLAGS)}

${eval _DFILES := ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.d'}}
${eval _DFILES += ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.di'}}
${eval _DFILES += $(WRAP_INFILES)}

${eval _INFILES := $(_DFILES)}

${call gen.line, # Object File - $(UNIT_TARGET)}
${call gen.line, # $(_TARGET)}

${call gen.line, $(_UNIT_TARGET_LOGS):}
${call gen.linetab, \$${eval DYNAMIC_INCFLAGS += -I$(DIR_SRC)/$(UNIT_DIR)}}
${call gen.linetab, \$${call log.header, $(_UNIT_TARGET).o}}
${call gen.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.lines, $(DYNAMIC_INCFLAGS)}}
${call gen.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.linetab, \$${call log.close}}
${call gen.space}

${call gen.line, $(_TARGET): $(_DFILES) $(UNIT_WRAPS_TARGETS) | $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)}
${call gen.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.space}
endef

define _unit.target.o-test
${eval _UNIT_TARGET := test-$(UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET).o-test-logs}
${eval _TARGET := $(DIR_BUILD_O)/$(_UNIT_TARGET).o}

${call debug, ------- [_unit.target.o] [$(_UNIT_TARGET)]}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -unittest}
${eval _DCFLAGS += -g}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _INCFLAGS := ${addprefix -I, $(LIB_DIRS_WORKSPACE)}}
${eval _INCFLAGS += $(WRAP_INCFLAGS)}

${eval _DFILES := ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.d'}}
${eval _DFILES += ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.di'}}
${eval _DFILES += $(WRAP_INFILES)}

${eval _INFILES := $(_DFILES)}

${call gen.line, # Test Object File - $(UNIT_TARGET)}
${call gen.line, # $(_TARGET)}

${call gen.line, $(_UNIT_TARGET_LOGS):}
${call gen.linetab, \$${eval DYNAMIC_INCFLAGS += -I$(DIR_SRC)/$(UNIT_DIR)}}
${call gen.linetab, \$${call log.header, $(_UNIT_TARGET).o}}
${call gen.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.linetab, \$${call log.lines, $(INCFLAGS)}}
${call gen.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.lines, $(DYNAMIC_INCFLAGS)}}
${call gen.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.linetab, \$${call log.close}}
${call gen.space}

${call gen.line, $(_TARGET): $(_DFILES) $(UNIT_WRAPS_TARGETS) | $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)}
${call gen.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.space}
endef