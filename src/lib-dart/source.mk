ifndef FIX_DFILES
SOURCE:=tagion
dfiles.mk:
	find $(SOURCE) -name "*.d" -a -not -name ".#*" -a -path "*tagion*" -printf "DFILES+=$(SOURCE)/%P\n" > dfiles.mk

clean-dfiles:
	rm -f dfiles.mk
endif
