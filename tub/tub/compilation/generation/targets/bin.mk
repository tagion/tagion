define _unit.target.bin
${eval _UNIT_DIR := $(UNIT_MAIN_DIR)}
${eval _UNIT_DEPS_TARGET := $(UNIT_MAIN_DEPS_TARGET)}
${eval _UNIT_TARGET := ${subst bin-, tagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET)-logs}

${call debug, ------- [_unit.target.bin] [$(UNIT_MAIN_TARGET)]}

${eval _TARGET := $(DIR_BUILD)/bins/$(_UNIT_TARGET)}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _OFILES := ${addprefix $(DIR_BUILD_O)/, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _OFILES += ${addprefix $(DIR_BUILD_O)/, $(_UNIT_TARGET:=.o)}}

${eval _INFILES := $(_OFILES)}

${call gen.line, # Bin Target - $(UNIT_TARGET)}
${call gen.line, # $(_TARGET)}

${call gen.line, $(_UNIT_TARGET_LOGS):}
${call gen.linetab, \$${call log.header, $(_UNIT_TARGET)}}
${call gen.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES LDCFLAGS}}
${call gen.linetab, \$${call log.separator}}
${call gen.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.linetab, \$${call log.kvp, INFILES}}
${call gen.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.linetab, \$${call log.close}}
${call gen.space}

${call gen.line, $(_UNIT_TARGET): $(_TARGET)}
${call gen.linetab, @}
${call gen.space}

${call gen.line, $(_TARGET): $(_OFILES) $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_LDCFLAGS)}
${call gen.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.space}
endef