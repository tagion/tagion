ifndef FIX_DFILES
SOURCE:=tagion
dfiles.mk: ${WAYS}
	@echo "########################################################################################"
	@echo "## DFILES"
	$(PRECMD)find $(SOURCE) -name "*.d" -a -not -name ".#*" -a -path "*tagion*" -printf "DFILES+=$(SOURCE)/%P\n" > dfiles.mk

CLEANER+=clean-dfiles

clean-dfiles:
	rm -f dfiles.mk
endif
