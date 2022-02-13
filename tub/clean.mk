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
	$(RMDIR) $(DBIN)

.PHONY: proper clean
