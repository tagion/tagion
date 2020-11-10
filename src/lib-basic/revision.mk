PACKAGE_MODULE?=tagion.$(PACKAGE)
$(REVISION):
	@echo "########################################################################################"
	@echo "## Linking $(1)"
	$(PRECMD)echo "module $(PACKAGE_MODULE).revision;" > $@
	$(PRECMD)echo 'enum REVNO=$(GIT_REVNO);' >> $@
	$(PRECMD)echo 'enum HASH="$(GIT_HASH)";' >> $@
