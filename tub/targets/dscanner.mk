
DSCANNER?=dscanner

D_LINT=$(DSCANNER) -S $(DINC) 

dscanner-lint:
	$(PRECMND)
	$(D_LINT)

dscanner-sloc:
	$(PRECMD)
	$(DSCANNER) --sloc src

dscanner-undoc:
	$(PRECMND)
	$(D_LINT) | grep -E " undocumented"

dscanner-services:
	echo XXX
	$(DSCANNER) -S src/lib-services/tagion| grep -E " undocumented"

help-dscanner:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.help, "make dscanner-lint", "Runs a linter on the source")
	$(call log.help, "make dscanner-sloc", "Counts the number of active code lines")
	$(call log.help, "make dscanner-undoc", "List the undocumented functions")
	$(call log.close)

.PHONY: help-dscanner

help: help-dscanner

