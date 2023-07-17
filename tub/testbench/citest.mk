

ci:
	$(MAKE) clean-trunk -f$(DTUB)/main.mk
	$(MAKE) clean-dartapi -f$(DTUB)/main.mk
	$(MAKE) bins -f$(DTUB)/main.mk
	$(RM) $(DLIB)/libtagion.$(LIBEXT)	
	$(MAKE) dartapi -f$(DTUB)/main.mk
	$(MAKE) bddtest unittest-cov TESTBENCH_FLAGS=--silent -f$(DTUB)/main.mk
	$(MAKE) release -f$(DTUB)/main.mk
	$(MAKE) ddoc -f$(DTUB)/main.mk
	cp $(REPOROOT)/collider_schedule.json $(DBIN) 
	$(MAKE) trunk -f$(DTUB)/main.mk
	#$(MAKE) test unittest-cov trunk bddreport -f$(DTUB)/main.mk

help-ci:
	${PRECMD}
	${call log.header, $@ :: help}
	${call log.help, "make ci", "Runs ci test and creates the trunk"}
	${call log.help, "make citest", "Runs the ci test $(TEST_STAGE)"}
	${call log.close}


.PHONY: help-ci

help: help-ci




