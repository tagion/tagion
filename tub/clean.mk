proper:
	$(PRECMD)
	${call log.header, $@ :: main}
	$(RMDIR) $(DBUILD)

clean:
	$(PRECMD)
	${call log.header, $@ :: main}

.PHONY: proper clean
