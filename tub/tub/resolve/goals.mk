# Parse command line arguments of make and initiate
# on-demand generation of targets:


RESOLVE_UNIT_TARGETS := ${filter resolve-%, $(MAKECMDGOALS)}

ifdef RESOLVE_UNIT_TARGETS
DEPS := $(subst resolve-,,$(RESOLVE_UNIT_TARGETS))
DEPS := $(sort $(DEPS))

${eval ${call debug.open, RESOLVE GOALS (LEVEL: $(MAKELEVEL))}}
${eval ${call debug, Defined MAKECMDGOALS: $(RESOLVE_UNIT_TARGETS)}}
${eval ${call debug.close, RESOLVE GOALS}}
${call debug.space}
endif