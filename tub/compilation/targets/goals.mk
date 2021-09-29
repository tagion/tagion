# Reset the generated file
${eval ${call gen.reset}}

# Parse command line arguments of make and initiate
# on-demand generation of targets:

COMPILE_UNIT_PREFIX_TARGETS := ${filter libtagion% tagion% testscope-libtagion% testall-libtagion% wrap-%, $(MAKECMDGOALS)}

ifdef COMPILE_UNIT_PREFIX_TARGETS
COMPILE_UNIT_LIB_TARGETS := ${filter libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_LIB_TARGETS += ${filter testall-libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_LIB_TARGETS += ${filter testscope-libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}

COMPILE_UNIT_BIN_TARGETS := ${filter tagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out testall-libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out testscope-libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}

COMPILE_UNIT_WRAP_TARGETS := ${filter wrap-%, $(COMPILE_UNIT_PREFIX_TARGETS)}

${eval ${call debug.open, GOALS}}
${eval ${call debug, Defined MAKECMDGOALS: $(COMPILE_UNIT_LIB_TARGETS) $(COMPILE_UNIT_BIN_TARGETS) $(COMPILE_UNIT_WRAP_TARGETS)}}
${eval ${call debug.close, GOALS}}
${call debug.space}

${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_LIB_TARGETS), ${eval ${call include.lib, $(COMPILE_UNIT_PREFIX_TARGET)}}}
${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_BIN_TARGETS), ${eval ${call include.bin, $(COMPILE_UNIT_PREFIX_TARGET)}}}
${foreach COMPILE_UNIT_PREFIX_TARGET, $(COMPILE_UNIT_WRAP_TARGETS), ${eval ${call include.wrap, $(COMPILE_UNIT_PREFIX_TARGET)}}}

${call gen.include}
endif