# Only tagion modules
.PHONY: clean proper clean-shared
clean: clean-shared
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/libs}
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/bins}
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)/.tmp}
	${call clean.ways, compiled files}

proper: clean-shared
	${eval WAYS_TO_CLEAN += $(DIR_BUILD)}
	${call clean.ways, compiled files}

clean-shared:
	${call log.header, cleaning ${strip $1}}
	$(PRECMD)rm -f $(DIR_SRC)/**/$(FILENAME_DEPS_MK) || true
	$(PRECMD)rm -f $(DIR_SRC)/**/$(FILENAME_TEST_DEPS_MK) || true
	${call log.line, Cleaned generated files}

# 
# Macros
# 
define clean.ways
$(PRECMD)${foreach CLEAN_DIR, $(WAYS_TO_CLEAN), rm -rf $(CLEAN_DIR);}
${call log.lines, $(WAYS_TO_CLEAN)}
${call log.close}
endef