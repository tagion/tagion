define dir.resolve
${dir ${lastword $(MAKEFILE_LIST)}}${strip $1}
endef

define dir.rm
$(PRECMD)mkdir -p $(DIR_TRASH)/${strip $1}
${call log.kvp, Trashed, ${strip $1}}
$(PRECMD)cp -rf ${strip $1} $(DIR_TRASH)/${strip $1} 2> /dev/null || true &
$(PRECMD)rm -rf ${strip $1} 2> /dev/null || true &
endef

define find.files
${shell find ${strip $1} -not -path "#*#" -not -path ".#*" ${foreach _EXCLUDE, $(SOURCE_FIND_EXCLUDE), -not -path "$(_EXCLUDE)"} -name '${strip $2}'}
endef