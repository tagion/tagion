LEVEL :=

define debug.space
${if $(MAKEDEBUG), ${info },}
endef

define debug.open
${eval LEVEL := ${LEVEL}--}
${if $(MAKEDEBUG), ${info $(LEVEL) \ ${strip $1}},}
endef

define debug
${if $(MAKEDEBUG), ${info $(LEVEL)--|   ${strip $1}},}
endef

define debug.close
${if $(MAKEDEBUG), ${info $(LEVEL) / ${strip $1}},}
${eval LEVEL := ${shell echo ${LEVEL} | cut -c3-}}
endef