# 
# Source code cloning
# 
add-%: $(DIR_SRC)/%/context.mk
	@

# TODO: Add branch name
# TODO: In isolated mode clone only --depth
$(DIR_SRC)/%/context.mk:
	$(PRECMD)git clone $(GIT_ORIGIN)/core-$(*) $(DIR_SRC)/$(*)	

add-core: ${addprefix add-, $(UNIT_LIST)}
	@