# 
# Clean
# 
clean:
	${call log.header, cleaning WAYS}
	${eval CLEAN_DIRS := ${foreach WAY, $(WAYS), ${dir $(WAY)}}}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}

clean/tests:
	${call log.header, cleaning WAYS}
	${eval CLEAN_DIRS := $(DIR_BUILD)/tests}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}

clean/bins:
	${call log.header, cleaning WAYS}
	${eval CLEAN_DIRS := $(DIR_BUILD)/bins}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}

clean/libs:
	${call log.header, cleaning WAYS}
	${eval CLEAN_DIRS := $(DIR_BUILD)/libs}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}

clean/all:
	${call log.header, cleaning WAYS and WAYS_PERSISTENT}
	${eval CLEAN_DIRS := ${foreach WAY, $(WAYS), ${dir $(WAY)}}}
	${eval CLEAN_DIRS += ${foreach WAY, $(WAYS_PERSISTENT), ${dir $(WAY)}}}
	$(PRECMD)${foreach CLEAN_DIR, $(CLEAN_DIRS), rm -rf $(CLEAN_DIR);}
	${call log.lines, $(CLEAN_DIRS)}
	${call log.close}