.PHONY: clean

clean: $(CLEANERS)
	${call log.header, cleaning...}
	$(PRECMD)${foreach _, $(TOCLEAN), rm -rf $(_);}
	${call log.lines, $(TOCLEAN)}
	${call log.close}