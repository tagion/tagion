
ADRDOX:= doc2

clean-doc:
	@echo Not implemented
	@echo cleaning docs

help-doc:
	$(PRECMD)
	${call log.header, $@ :: help}
	${cal llog.help, "make docs", "Create the docs with addrdox"}

doc:
	@echo making docs
	doc2 -i --skeleton ${DTUB}/docs_template/skeleton.html -o $(REPOROOT)/build/doc $(abspath $(REPOROOT)/src)
