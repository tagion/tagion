
test: unittest bddreport

.PHONY: test

help-test:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-test", "Will display this part"}
	${call log.help, "make test", "Will compile and run all tests"}
	${call log.help, "make clean-test", "Will clean all test logs"}
	${call log.close}

.PHONY: help-test

help: help-test

clean-test: clean-unittest clean-bddtest 
