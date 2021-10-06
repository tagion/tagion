define _unit.target.o
${eval _UNIT_TARGET := $(UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET).o-logs}
${eval _TARGET := $(DIR_BUILD_O)/$(_UNIT_TARGET).o}

${call debug.open, GENERATION (.o) $(_UNIT_TARGET)}

${eval _DCFLAGS_TEST := -unittest}
${eval _DCFLAGS_TEST += -g}
${eval _DCFLAGS := $(DCFLAGS)}
${eval _DCFLAGS += -c}
${eval _DCFLAGS += -of$(_TARGET)}

${eval _LDCFLAGS := $(LDCFLAGS)}

${eval _INCFLAGS := ${addprefix -I, $(LIB_DIRS_WORKSPACE)}}
${eval _INCFLAGS += $(WRAP_INCFLAGS)}

${eval _INFILES := ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.d'}}
${eval _INFILES += ${shell find $(DIR_SRC)/$(UNIT_DIR) -not -path "$(SOURCE_FIND_EXCLUDE)" -name '*.di'}}
${eval _INFILES += $(WRAP_INFILES)}

${call gen.o.line, # ${notdir $(_TARGET)}}
${call gen.o.line, # Files: ${notdir $(_INFILES)} ${notdir $(UNIT_WRAPS_TARGETS)}}
${call gen.o.line, $(_TARGET): $(_INFILES) $(UNIT_WRAPS_TARGETS) $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.o.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS) $(_INFILES) \$$(_UNIT_WRAPS_INCFLAGS) $(_INCFLAGS) $(_LDCFLAGS)}
${call gen.o.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.o.line,}

${call gen.o.line, $(UNIT_TARGET)-context: $(UNIT_WRAPS_TARGETS) ${addsuffix -context, $(UNIT_DEPS_TARGET)}}
${call gen.o.linetab, \$${eval _UNIT_WRAPS_INCFLAGS += $(UNIT_WRAPS_INCFLAGS)}}
${call gen.o.linetab, \$${eval _UNIT_WRAPS_LINKFILES += $(UNIT_WRAPS_LINKFILES)}}
${call gen.o.linetab, @}
${call gen.o.line,}

${call debug, Generated target: $(_TARGET)}

${call gen.logs.line, $(_UNIT_TARGET_LOGS): | reset-wrap-context $(UNIT_TARGET)-context}
${call gen.logs.linetab, \$${call log.header, $(_UNIT_TARGET).o}}
${call gen.logs.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.logs.linetab, \$${call log.separator}}
${call gen.logs.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.logs.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS)}}
${call gen.logs.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.logs.linetab, \$${call log.kvp, INFILES}}
${call gen.logs.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.logs.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.logs.linetab, \$${call log.lines, \$$(_UNIT_WRAPS_INCFLAGS)}}
${call gen.logs.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.logs.linetab, \$${call log.close}}
${call gen.logs.line,}

# ------------------------------ 
# For unit testing:

${eval _UNIT_TARGET := test-$(UNIT_TARGET)}
${eval _UNIT_TARGET_LOGS := $(_UNIT_TARGET).o-test-logs}
${eval _TARGET := $(DIR_BUILD_O)/$(_UNIT_TARGET).o}

${call gen.o.line, # ${notdir $(_TARGET)}}
${call gen.o.line, $(_TARGET): $(_INFILES) $(UNIT_WRAPS_TARGETS) | $(_TARGET).way $(_UNIT_TARGET_LOGS)}
${call gen.o.linetab, \$$(PRECMD)\$$(DC) $(_DCFLAGS_TEST) $(_DCFLAGS) $(_INFILES) $(_INCFLAGS) $(_LDCFLAGS)}
${call gen.o.linetab, \$${call log.kvp, Compiled, $(_TARGET)}}
${call gen.o.line,}

${call debug, Generated target: $(_TARGET)}

${call gen.logs.line, $(_UNIT_TARGET_LOGS):}
${call gen.logs.linetab, \$${call log.header, $(_UNIT_TARGET).o}}
${call gen.logs.linetab, \$${call log.kvp, Command, DC DCFLAGS INFILES INCFLAGS LDCFLAGS}}
${call gen.logs.linetab, \$${call log.separator}}
${call gen.logs.linetab, \$${call log.kvp, DC, $(DC)}}
${call gen.logs.linetab, \$${call log.kvp, DCFLAGS, $(_DCFLAGS_TEST) $(_DCFLAGS)}}
${call gen.logs.linetab, \$${call log.kvp, LDCFLAGS, $(_LDCFLAGS)}}
${call gen.logs.linetab, \$${call log.kvp, INFILES}}
${call gen.logs.linetab, \$${call log.lines, $(_INFILES)}}
${call gen.logs.linetab, \$${call log.kvp, INCFLAGS}}
${call gen.logs.linetab, \$${call log.lines, $(_INCFLAGS)}}
${call gen.logs.linetab, \$${call log.close}}
${call gen.logs.line,}

${call debug.close, GENERATION (.o) $(_UNIT_TARGET)}
endef