proper: TOCLEAN := $(DTMP)
proper: TOCLEAN += $(DBIN)
proper: TOCLEAN += $(TOPROPER)
proper: clean
	@

.PHONY: clean
clean: TOCLEAN += $(DTMP)/*.o
clean: TOCLEAN += $(DBIN)
clean:
	${call log.header, clean}
	$(PRECMD)${foreach _, $(TOCLEAN), $(RMDIR) $(_) > /dev/null || true;}
	${call log.lines, $(TOCLEAN)}
	${call log.close}