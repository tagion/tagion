-include ${shell find $(DIR_SRC) -name '*local.mk'}
-include ${shell find $(DIR_SRC) -name '*context.mk'}

INCLFLAGS_SRC := ${shell ls -d src/*/ | grep -v wrap- | grep -v bin-}


DEPS += 1
# 
# Target shortcuts
# 
libtagion%:
	@
	
libtagion%.o: | libtagion%.ctx 
	@echo .o - $(DEPS)


define find.files
${shell find ${strip $1} -not -path "#*#" -not -path ".#*" ${foreach _EXCLUDE, $(SOURCE_FIND_EXCLUDE), -not -path "$(_EXCLUDE)"} -name '${strip $2}'}
endef