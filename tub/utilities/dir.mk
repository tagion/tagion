define dir.resolve
${dir ${lastword $(MAKEFILE_LIST)}}${strip $1}
endef

#
# Find the matching path
# $1 is the path
#
define dir.resolve_1
${lastword ${shell find $(REPOROOT) -type d -path "*${strip $1}"}}
endef

