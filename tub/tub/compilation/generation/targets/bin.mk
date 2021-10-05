define _unit.target.bin
${eval _UNIT_DIR := $(UNIT_MAIN_DIR)}
${eval _UNIT_DEPS_TARGET := $(UNIT_MAIN_DEPS_TARGET)}
${eval _UNIT_TARGET := ${subst bin-, tagion, $(_UNIT_DIR)}}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET)-logs}

${call debug.open, GENERATION (bin) $(_UNIT_TARGET)}

${eval _TARGET := $(DIR_BUILD)/bins/$(_UNIT_TARGET)}

${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _OFILES := ${addprefix $(DIR_BUILD_O)/, $(_UNIT_DEPS_TARGET:=.o)}}
${eval _OFILES += ${addprefix $(DIR_BUILD_O)/, $(_UNIT_TARGET:=.o)}}

${eval _INFILES := $(_OFILES)}

${call gen.bin.line, # Bin Target - $(UNIT_TARGET)}
${call gen.bin.line, # $(_TARGET)}

${call gen.bin.line, $(_UNIT_TARGET_LOGS):}
${call gen.bin.linetab, \$${call log.header, $(_UNIT_TARGET)}}
${call gen.bin.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES LDCFLAGS}}
${call gen.bin.linetab, \$${call log.separator}}
${call gen.bin.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.bin.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.bin.linetab, \$${call log.kvp, INFILES}}
${call gen.bin.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.bin.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.bin.linetab, \$${call log.close}}
${call gen.bin.line,}

${call debug, Generated target: $(_UNIT_TARGET_LOGS)}

${call gen.bin.line, $(_UNIT_TARGET): $(_TARGET)}
${call gen.bin.linetab, @}
${call gen.bin.line,}

${call debug, Generated target: $(_UNIT_TARGET)}

${call gen.bin.line, $(_TARGET): $(_OFILES) $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.bin.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) $(_LDCFLAGS)}
${call gen.bin.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.bin.line,}

${call debug, Generated target: $(_TARGET)}

${call debug.close, GENERATION (bin) $(_UNIT_TARGET)}
endef