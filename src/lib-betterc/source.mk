gen.dfiles.mk: ${WAYS}
	@echo "########################################################################################"
	@echo "## DFILES"
	$(PRECMD)find $(SOURCE) -name "*.d" -a -not -name ".#*" -a -path "*$(SOURCE)*" -printf "DFILES+=$(SOURCE)/%P\n" > $@

CLEANER+=clean-dfiles

clean-dfiles:
	rm -f gen.dfiles.mk
