.PHONY: init
branch-%: 
	${call log.header, creating local.generated.mk}
	$(PRECMD)echo "# This file is Generated. Contents can be overriden automatically." > $(DIR_TUB_ROOT)/local.generated.mk
	$(PRECMD)echo BRANCH = $(*) >> $(DIR_TUB_ROOT)/local.generated.mk