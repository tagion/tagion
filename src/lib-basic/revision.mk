$(REVISION):
	@echo "########################################################################################"
	@echo "## Linking $(1)"
	$(PRECMD)echo "module $(PACKAGE).revision;" > $@
	$(PRECMD)echo 'enum REVNO=$(REVNO);' >> $@
	$(PRECMD)echo 'enum HASH="$(HASH)";' >> $@
