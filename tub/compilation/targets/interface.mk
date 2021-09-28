# Unit declaration
define unit.lib
${eval ${call _unit.lib, $1}}
endef

define unit.bin
${eval ${call _unit.bin, $1}}
endef

define unit.wrap
${eval ${call _unit.wrap, $1}}
endef

# Unit declaration of dependencies
define unit.dep.lib
${eval ${call _unit.dep.lib, $1}}
endef

define unit.dep.wrap
${eval ${call _unit.dep.wrap, $1}}
endef

# Unit declaration ending
define unit.end
${eval ${call _unit.end.safe}}
endef