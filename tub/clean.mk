proper:
	$(PRECMD)
	${call log.header, $@ :: main}
	$(RMDIR) $(DBUILD)

proper-all:
	$(PRECMD)
	${call log.header, $@ :: main}
	$(RMDIR) $(BUILD)

clean:
	$(PRECMD)
	${call log.header, $@ :: main}

clean-bin:
	$(PRECMD)
	${call log.header, $@ :: main}
	$(RMDIR) $(DBIN)

clean: clean-bin

.PHONY: proper clean clean-bin
