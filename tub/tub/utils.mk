define dir_self
$(dir $(lastword $(MAKEFILE_LIST)))
endef