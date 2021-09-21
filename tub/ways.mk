DIRS_LIBS := ${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}

# 
# Creating required directories
# 
%.way:
	$(PRECMD)mkdir -p $(@D)

WAYS += $(DIR_BUILD_TEMP)/o/.way
WAYS += $(DIR_BUILD)/libs/.way
WAYS += $(DIR_BUILD)/bins/.way

ways: $(WAYS)