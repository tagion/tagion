.PHONY: clean

clean-build: TOCLEAN := $(DTMP)/*.o
clean-build: TOCLEAN += $(DBIN)
clean-build: clean
	@

clean:
	${call log.header, clean}
	$(PRECMD)${foreach _, $(TOCLEAN), $(RMDIR) $(_) > /dev/null || true;}
	${call log.lines, $(TOCLEAN)}
	${call log.close}