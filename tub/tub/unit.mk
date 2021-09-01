UNITS_DEFINED := _

# 
# Interface
# 
define unit.lib
${eval ${call _unit.start, $1}}
endef

define unit.dep.lib
${eval ${call _unit.dep.lib, $1}}
endef

define unit.end
${eval ${call _unit.end}}
endef

# 
# Implementation
# 
define _unit.vars.reset
UNIT_DEPS :=
UNIT_DEPS_TARGETS :=
UNIT :=
endef

define _unit.start
${info -> start unit ${strip $1}, at this point already defined: $(UNITS_DEFINED)}
${call _unit.vars.reset}
UNIT := ${strip $1}
endef

define _unit.dep.lib
${info -> add lib ${strip $1} to $(UNIT)}
UNIT_DEPS += ${strip $1}
UNIT_DEPS_TARGETS += libtagion${strip $1}
endef

define _unit.end
${info -> $(UNIT) defined, deps: $(UNIT_DEPS)}
UNITS_DEFINED += $(UNIT)
libtagion$(UNIT): $(UNIT_DEPS_TARGETS)
	@echo "This is $(UNIT), it depends on $(UNIT_DEPS_TARGETS)"

# Remove dependencies that were already included
${foreach UNIT_DEFINED, $(UNITS_DEFINED), ${eval UNIT_DEPS := ${patsubst $(UNIT_DEFINED),,$(UNIT_DEPS)}}}
${foreach UNIT_DEP, $(UNIT_DEPS), ${eval include $(DIR_SRC)/lib-$(UNIT_DEP)/context.mk}}
endef