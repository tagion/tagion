define _unit.target.lib
${eval _UNIT_DIR := $(UNIT_MAIN_DIR)}
${eval _UNIT_DEPS_TARGET := $(UNIT_MAIN_DEPS_TARGET)}
${eval _UNIT_TARGET := ${subst lib-, libtagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET)-logs}

${call debug.open, GENERATION (lib) $(UNIT_MAIN_TARGET)}

${eval _TARGET := $(DIR_BUILD)/libs/$(_UNIT_TARGET).a}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _INFILES := ${addprefix $(DIR_BUILD_O)/, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _INFILES += ${addprefix $(DIR_BUILD_O)/, $(_UNIT_TARGET:=.o)}}

${call gen.lib.line, # ${notdir $(_TARGET)}: ${notdir $(_INFILES)}}
${call gen.lib.line, # Files: ${notdir $(_INFILES)}}
${call gen.lib.line, $(_TARGET): $(_INFILES) $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.lib.linetab, \$$(PRECMD)ar cr $(_TARGET) $(_INFILES)}
${call gen.lib.linetab, \$${call log.kvp, Archived, $(_TARGET)}}
${call gen.lib.line,}

${call gen.lib.line, $(_UNIT_TARGET): $(_TARGET)}
${call gen.lib.linetab, @}
${call gen.lib.line,}

${call debug, Generated target: $(_UNIT_TARGET)}
${call debug, Generated target: $(_TARGET)}

# Logs:
${call gen.logs.line, $(_UNIT_TARGET_LOGS):}
${call gen.logs.linetab, \$${call log.header, $(_UNIT_TARGET).a}}
${call gen.logs.linetab, \$${call log.kvp, Command, ar cr TARGET INFILES}}
${call gen.logs.linetab, \$${call log.separator}}
${call gen.logs.linetab, \$${call log.kvp, TARGET, $(_TARGET)}}
${call gen.logs.linetab, \$${call log.kvp, INFILES}}
${call gen.logs.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.logs.linetab, \$${call log.close}}
${call gen.logs.line,}

# ------------------------------ 
# For unit testing in ALL mode:

${eval _UNIT_TARGET := ${subst lib-, libtagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_FULL := testscope-$(_UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET_FULL)-logs}

${eval _TARGET := $(DIR_BUILD)/bins/$(_UNIT_TARGET_FULL)}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -main}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _INFILES := ${addprefix $(DIR_BUILD_O)/, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _INFILES += ${addprefix $(DIR_BUILD_O)/test-, $(_UNIT_TARGET:=.o)}}

${call gen.test.line, # ${notdir $(_TARGET)}: ${notdir $(_INFILES)}}
${call gen.test.line, # Files: ${notdir $(_INFILES)}}
${call gen.test.line, $(_TARGET): $(_INFILES) $(_UNIT_TARGET_LOGS)}
${call gen.test.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_LDCFLAGS)}
${call gen.test.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.test.line,}

${call gen.test.line, .PHONY:  $(_UNIT_TARGET_FULL)}
${call gen.test.line, $(_UNIT_TARGET_FULL): $(_TARGET)}
${call gen.test.linetab, $(PRECMD)$(_TARGET)}
${call gen.test.line,}

${call debug, Generated target: $(_TARGET)}

# Logs:
${call gen.logs.line, $(_UNIT_TARGET_LOGS):}
${call gen.logs.linetab, \$${call log.header, $(_UNIT_TARGET_FULL)}}
${call gen.logs.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES LDCFLAGS}}
${call gen.logs.linetab, \$${call log.separator}}
${call gen.logs.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.logs.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.logs.linetab, \$${call log.kvp, INFILES}}
${call gen.logs.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.logs.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.logs.linetab, \$${call log.close}}
${call gen.logs.line,}

# ------------------------------ 
# For unit testing in SCOPE mode:

${eval _UNIT_TARGET := ${subst lib-, libtagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_FULL := testall-$(_UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET_FULL)-logs}

${eval _TARGET := $(DIR_BUILD)/bins/$(_UNIT_TARGET_FULL)}

${eval _INFILES := ${addprefix $(DIR_BUILD_O)/test-, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _INFILES += ${addprefix $(DIR_BUILD_O)/test-, $(_UNIT_TARGET:=.o)}}

${call gen.test.line, # ${notdir $(_TARGET)}: ${notdir $(_INFILES)}}
${call gen.test.line, # Files: ${notdir $(_INFILES)}}
${call gen.test.line, $(_TARGET): $(_INFILES) $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.test.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_LDCFLAGS)}
${call gen.test.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.test.line,}

${call gen.test.line, .PHONY:  $(_UNIT_TARGET_FULL)}
${call gen.test.line, $(_UNIT_TARGET_FULL): $(_TARGET)}
${call gen.test.linetab, $(PRECMD)$(_TARGET)}
${call gen.test.line,}

${call debug, Generated target: $(_TARGET)}

${call gen.logs.line, $(_UNIT_TARGET_LOGS):}
${call gen.logs.linetab, \$${call log.header, $(_UNIT_TARGET_FULL)}}
${call gen.logs.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.logs.linetab, \$${call log.separator}}
${call gen.logs.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.logs.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.logs.linetab, \$${call log.kvp, INFILES}}
${call gen.logs.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.logs.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.logs.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.logs.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.logs.linetab, \$${call log.close}}
${call gen.logs.line,}

${call debug.close, GENERATION (lib) $(UNIT_MAIN_TARGET)}
endef