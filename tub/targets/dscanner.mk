
DSCANNER?=dscanner

D_LINT=$(DSCANNER) -S $(DINC) 

dscanner-lint:
	$(PRECMND)
	$(D_LINT)


dscanner-undoc:
	$(PRECMND)
	$(D_LINT) | grep -E " undocumented"

dscanner-services:
	echo XXX
	$(DSCANNER) -S src/lib-services/tagion| grep -E " undocumented"




