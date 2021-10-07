# Only tagion modules
.PHONY: clean
clean:
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/libs}
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/bins}
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/.tmp}
	${call clean.ways, compiled files}

# 
# Macros
# 
define clean.ways
${call log.header, cleaning ${strip $1}}
$(PRECMD)${foreach CLEAN_DIR, $(WAYS_TO_CLEAN), rm -rf $(CLEAN_DIR);}
${call log.lines, $(WAYS_TO_CLEAN)}
${call log.close}
endef