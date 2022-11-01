#
# Resolves the directory for the current .mk file
#
define dir.resolve
${dir ${lastword $(MAKEFILE_LIST)}}${strip $1}
endef

#
# Find the matching path
# $1 is the path
#
define dir.match
${lastword ${shell find $(REPOROOT) -type d -path "*${strip $1}"}}
endef

