.PHONY: init
version-%: 
	${call log.header, creating local.branch.mk}
	$(PRECMD)echo BRANCH = $(*) > $(DIR_TUB_ROOT)/local.branch.mk