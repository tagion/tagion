# Creating directories
%.way:
	$(PRECMD)mkdir -p $(@D)

WAYS += $(DIR_BUILD_TEMP)/o/.way
WAYS += $(DIR_BUILD)/libs/.way
WAYS += $(DIR_BUILD)/bins/.way

ways: $(WAYS)