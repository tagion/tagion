define _unit.target.lib-testscope
${eval _UNIT_DIR := $(UNIT_MAIN_DIR)}
${eval _UNIT_DEPS_TARGET := $(UNIT_MAIN_DEPS_TARGET)}
${eval _UNIT_TARGET := ${subst lib-, libtagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_FULL := testscope-$(_UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET_FULL)-logs}

${call debug, ------- [_unit.target.lib-testscope] [$(UNIT_MAIN_TARGET)]}

${eval _TARGET := $(DIR_BUILD)/bins/$(_UNIT_TARGET_FULL)}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -main}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _OFILES := ${addprefix $(DIR_BUILD_O)/, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _OFILES += ${addprefix $(DIR_BUILD_O)/test-, $(_UNIT_TARGET:=.o)}}

${eval _INFILES := $(_OFILES)}

${call gen.line, # Test Scope Target - $(UNIT_TARGET)}
${call gen.line, # $(_TARGET)}

${call gen.line, $(_UNIT_TARGET_LOGS):}
${call gen.linetab, \$${call log.header, $(_UNIT_TARGET_FULL)}}
${call gen.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.linetab, \$${call log.close}}
${call gen.space}

${call gen.line, .PHONY:  $(_UNIT_TARGET_FULL)}
${call gen.line, $(_UNIT_TARGET_FULL): $(_TARGET)}
${call gen.linetab, $(PRECMD)$(_TARGET)}
${call gen.space}

${call gen.line, $(_TARGET): $(_OFILES) $(_UNIT_TARGET_LOGS)}
${call gen.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_LDCFLAGS)}
${call gen.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.space}
endef

define _unit.target.lib-testall
${eval _UNIT_DIR := $(UNIT_MAIN_DIR)}
${eval _UNIT_DEPS_TARGET := $(UNIT_MAIN_DEPS_TARGET)}
${eval _UNIT_TARGET := ${subst lib-, libtagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_FULL := testall-$(_UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET_FULL)-logs}

${call debug, ------- [_unit.target.lib-testall] [$(UNIT_MAIN_TARGET)]}

${eval _TARGET := $(DIR_BUILD)/bins/$(_UNIT_TARGET_FULL)}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -main}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _OFILES := ${addprefix $(DIR_BUILD_O)/test-, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _OFILES += ${addprefix $(DIR_BUILD_O)/test-, $(_UNIT_TARGET:=.o)}}

${eval _INFILES := $(_OFILES)}

${call gen.line, # Test All Target - $(UNIT_TARGET)}
${call gen.line, # $(_TARGET)}

${call gen.line, $(_UNIT_TARGET_LOGS):}
${call gen.linetab, \$${call log.header, $(_UNIT_TARGET_FULL)}}
${call gen.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.linetab, \$${call log.close}}
${call gen.space}

${call gen.line, .PHONY:  $(_UNIT_TARGET_FULL)}
${call gen.line, $(_UNIT_TARGET_FULL): $(_TARGET)}
${call gen.linetab, $(PRECMD)$(_TARGET)}
${call gen.space}

${call gen.line, $(_TARGET): $(_OFILES) $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_LDCFLAGS)}
${call gen.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.space}
endef

define _unit.target.lib
${eval _UNIT_DIR := $(UNIT_MAIN_DIR)}
${eval _UNIT_DEPS_TARGET := $(UNIT_MAIN_DEPS_TARGET)}
${eval _UNIT_TARGET := ${subst lib-, libtagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET)-logs}

${call debug, ------- [_unit.target.lib] [$(UNIT_MAIN_TARGET)]}

${eval _TARGET := $(DIR_BUILD)/bins/$(_UNIT_TARGET)}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -main}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _OFILES := ${addprefix $(DIR_BUILD_O)/, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _OFILES += ${addprefix $(DIR_BUILD_O)/, $(_UNIT_TARGET:=.o)}}

${eval _INFILES := $(_OFILES)}

${call gen.line, # Lib Target - $(UNIT_TARGET)}
${call gen.line, # $(_TARGET)}

${call gen.line, $(_UNIT_TARGET_LOGS):}
${call gen.linetab, \$${call log.header, $(_UNIT_TARGET).a}}
${call gen.linetab, \$${call log.kvp, Command, ar cr TARGET INFILES}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, TARGET, $(_TARGET)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.close}}
${call gen.space}

${call gen.line, $(_UNIT_TARGET): $(_TARGET)}
${call gen.linetab, @}
${call gen.space}

${call gen.line, $(_TARGET): $(_OFILES) $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.linetab, \$$(PRECMD)ar cr $(_TARGET) $(_INFILES)}
${call gen.linetab, \$${call log.kvp, Archived, $(_TARGET)}}
${call gen.space}
endef