$(REVISION):
	@echo "########################################################################################"
	@echo "## Linking $(1)"
	$(PRECMD)echo "module $(PACKAGE).revision;" > $@
	$(PRECMD)echo 'enum REVNO=$(GIT_REVNO);' >> $@
	$(PRECMD)echo 'enum HASH="$(GOT_HASH)";' >> $@
