.PHONY: clean

CLEANERS += clean-build
clean-build:
	${call log.header, clean build}
	${call log.lines, $(DTMP)}
	$(PRECMD)$(RMDIR) $(DTMP) > /dev/null || true
	${call log.lines, $(DBIN)}
	$(PRECMD)$(RMDIR) $(DBIN) > /dev/null || true
	${call log.close}

clean: $(CLEANERS)
	${call log.header, clean}
	$(PRECMD)${foreach _, $(TOCLEAN), $(RMDIR) $(_) > /dev/null || true;}
	${call log.lines, $(TOCLEAN)}
	${call log.close}