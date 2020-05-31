dfiles.mk: ${WAYS}
	@echo "########################################################################################"
	@echo "## DFILES"
	$(PRECMD)find $(SOURCE) -name "*.d" -a -not -name ".#*" -a -path "*$(SOURCE)*" -printf "DFILES+=$(SOURCE)/%P\n" > dfiles.mk

CLEANER+=clean-dfiles

clean-dfiles:
	rm -f dfiles.mk
