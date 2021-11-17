.PHONY: clean

clean: $(CLEANERS)
	${call log.header, cleaning...}
	$(PRECMD)${foreach _, $(TOCLEAN), $(RMDIR) $(_);}
	${call log.lines, $(TOCLEAN)}
	${call log.close}