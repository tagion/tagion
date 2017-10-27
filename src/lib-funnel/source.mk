
dfiles.mk:
	find . -name "*.d" -a -not -name ".#*" -a -path "*bakery*" -printf "DFILES+=%P\n" > dfiles.mk

clean-dfiles:
	rm -f dfiles.mk
