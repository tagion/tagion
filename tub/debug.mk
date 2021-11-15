MK_DEBUG_LEVEL :=

define debug.space
${if $(MK_DEBUG), ${info },}
endef

define debug.open
${eval MK_DEBUG_LEVEL := ${MK_DEBUG_LEVEL}--}
${if $(MK_DEBUG), ${info $(MK_DEBUG_LEVEL) \ ${strip $1}},}
endef

define debug
${if $(MK_DEBUG), ${info $(MK_DEBUG_LEVEL)--|   ${strip $1}},}
endef

define debug.lines
${foreach LINE,${strip $1},${if $(MK_DEBUG), ${info $(MK_DEBUG_LEVEL)--|   $(LINE)},}}
endef

define debug.close
${if $(MK_DEBUG), ${info $(MK_DEBUG_LEVEL) / ${strip $1}},}
${eval MK_DEBUG_LEVEL := ${shell echo ${MK_DEBUG_LEVEL} | cut -c3-}}
endef