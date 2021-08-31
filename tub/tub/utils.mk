define dir.self
${dir ${lastword $(MAKEFILE_LIST)}}${strip $1}
endef

define unit.start
UNIT := ${strip $1}
UNIT_DEPS :=
endef

define unit.dep.lib
include $(DIR_SRC)/lib-${strip $1}/context.mk
UNIT_DEPS += libtagion${strip $1}
endef

define unit.end
$(UNIT): 
UNIT := 
endef