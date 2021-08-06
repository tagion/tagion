define dir.self
${dir ${lastword $(MAKEFILE_LIST)}}${strip $1}
endef