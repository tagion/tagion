# 
# Source code cloning
# 
add/lib/%: $(DIR_LIBS)/%/context.mk
	@

$(DIR_LIBS)/%/context.mk:
	$(PRECMD)git clone $(GIT_ORIGIN)/core-lib-$(*) $(DIR_LIBS)/$(*)	

add/bin/%: $(DIR_BINS)/%/context.mk
	@

$(DIR_BINS)/%/context.mk:	
	$(PRECMD)git clone $(GIT_ORIGIN)/core-bin-$(*) $(DIR_BINS)/$(*)

add/wrap/%: $(DIR_WRAPS)/%/Makefile
	@

$(DIR_WRAPS)/%/Makefile:
	$(PRECMD)git clone $(GIT_ORIGIN)/core-wrap-$(*) $(DIR_WRAPS)/$(*)