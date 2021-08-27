# 
# Only tagion modules
# 
clean:
	${eval WAYS_TO_CLEAN := ${foreach WAY, $(WAYS), ${dir $(WAY)}}}
	${call clean.ways, WAYS}

# 
# Tagion modules and wraps
# 
clean-all:
	${eval WAYS_TO_CLEAN := ${foreach WAY, $(WAYS), ${dir $(WAY)}}}
	${eval WAYS_TO_CLEAN += ${foreach WAY, $(WAYS_PERSISTENT), ${dir $(WAY)}}}
	${call clean.ways, WAYS and WAYS_PERSISTENT}

# 
# Grouped targets
# 
clean-tests:
	${eval WAYS_TO_CLEAN := $(DIR_BUILD)/tests}
	${call clean.ways, WAYS}

clean-bins:
	${eval WAYS_TO_CLEAN := $(DIR_BUILD)/bins}
	${call clean.ways, WAYS}

clean-libs:
	${eval WAYS_TO_CLEAN := $(DIR_BUILD)/libs}
	${call clean.ways, libtagion$(*)}

# 
# Specific targets
# 
clean-libtagion%:
	${eval WAYS_TO_CLEAN := $(DIR_BUILD)/libs/o/libtagion$(*).o}
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/libs/static/libtagion$(*).a}
	${call clean.ways, libtagion$(*)}

clean-tagion%:
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/bins/tagion$(*).a}
	${call clean.ways, tagion$(*)}

clean-test_libtagion%:
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/tests/test_libtagion$(*).a}
	${call clean.ways, test_libtagion$(*)}

clean-wrap-%:
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/wraps/$(*)}
	${call clean.ways, tagion$(*)}

# 
# Macros
# 
define clean.ways
${call log.header, cleaning ${strip $1}}
$(PRECMD)${foreach CLEAN_DIR, $(WAYS_TO_CLEAN), rm -rf $(CLEAN_DIR);}
${call log.lines, $(WAYS_TO_CLEAN)}
${call log.close}
endef