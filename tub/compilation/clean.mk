# Only tagion modules
# TODO: Restore clean logic
clean:
	@

# 
# Macros
# 
define clean.ways
${call log.header, cleaning ${strip $1}}
$(PRECMD)${foreach CLEAN_DIR, $(WAYS_TO_CLEAN), rm -rf $(CLEAN_DIR);}
${call log.lines, $(WAYS_TO_CLEAN)}
${call log.close}
endef