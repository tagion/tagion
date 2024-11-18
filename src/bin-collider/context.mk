
COLLIDER_DFILES:=$(shell find $(DSRC)/bin-collider/ -name "*.d" -a -not -name "collider.d")

UNITTEST_DFILES+=$(COLLIDER_DFILES)

test88:
	@echo $(COLLIDER_DFILES)
