define dir.resolve
${dir ${lastword $(MAKEFILE_LIST)}}${strip $1}
endef