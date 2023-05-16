

ci:
	$(MAKE) clean-trunk -f$(DTUB)/main.mk
	$(MAKE) bins -f$(DTUB)/main.mk
	$(MAKE) bddtest unittest-cov -f$(DTUB)/main.mk
	$(MAKE) ddoc -f$(DTUB)/main.mk
	$(MAKE) trunk -f$(DTUB)/main.mk
	$(MAKE) bddreport -f$(DTUB)/main.mk
	#$(MAKE) test unittest-cov trunk bddreport -f$(DTUB)/main.mk

help-ci:
	${PRECMD}
	${call log.header, $@ :: help}
	${call log.help, "make ci", "Runs ci test and creates the trunk"}
	${call log.help, "make citest", "Runs the ci test $(TEST_STAGE)"}
	${call log.close}


.PHONY: help-ci

help: help-ci




