# Parse command line arguments of make and initiate
# on-demand generation of targets:

COMPILE_UNIT_PREFIX_TARGETS := ${filter libtagion% tagion% test-libtagion% wrap-% resolve-%, $(MAKECMDGOALS)}

ifdef COMPILE_UNIT_PREFIX_TARGETS
COMPILE_UNIT_LIB_TARGETS := ${filter libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_LIB_TARGETS += ${filter test-libtagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}

COMPILE_UNIT_LIB_DIRS := ${subst libtagion,lib-,$(COMPILE_UNIT_LIB_TARGETS)}

COMPILE_UNIT_BIN_TARGETS := ${filter tagion%, $(COMPILE_UNIT_PREFIX_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}
COMPILE_UNIT_BIN_TARGETS := ${filter-out test-libtagion%, $(COMPILE_UNIT_BIN_TARGETS)}

COMPILE_UNIT_BIN_DIRS := ${subst tagion,bin-,$(COMPILE_UNIT_BIN_TARGETS)}

COMPILE_UNIT_WRAP_TARGETS := ${filter wrap-%, $(COMPILE_UNIT_PREFIX_TARGETS)}

DEPS += ${filter resolve-%, $(COMPILE_UNIT_PREFIX_TARGETS)}
DEPS := $(subst resolve-,,$(DEPS))
DEPS += $(COMPILE_UNIT_LIB_DIRS)
DEPS += $(COMPILE_UNIT_BIN_DIRS)
DEPS := $(sort $(DEPS))

${eval ${call debug.open, GOALS}}
${eval ${call debug, Defined MAKECMDGOALS: $(COMPILE_UNIT_LIB_TARGETS) $(COMPILE_UNIT_BIN_TARGETS) $(COMPILE_UNIT_WRAP_TARGETS) $(RESOLVE_UNIT_TARGETS)}}
${eval ${call debug.close, GOALS}}
${call debug.space}
endif