

ci:
	$(MAKE) -S clean-trunk -f$(DTUB)/main.mk
	$(MAKE) -S bins -f$(DTUB)/main.mk
	$(MAKE) -S bddtest unittest-cov TESTBENCH_FLAGS=--silent -f$(DTUB)/main.mk
	$(MAKE) -S release -f$(DTUB)/main.mk
	$(MAKE) -S ddoc -f$(DTUB)/main.mk
	cp $(REPOROOT)/collider_schedule.json $(DBIN) 
	cp $(DSRC)/bin-wave/neuewelle.service $(DBIN)
	cp $(DTUB)/scripts/create_wallets.sh $(DBIN)
	$(MAKE) -S trunk -f$(DTUB)/main.mk
	#$(MAKE) -S test unittest-cov trunk bddreport -f$(DTUB)/main.mk

help-ci:
	${PRECMD}
	${call log.header, $@ :: help}
	${call log.help, "make ci", "Runs ci test and creates the trunk"}
	${call log.help, "make citest", "Runs the ci test $(TEST_STAGE)"}
	${call log.close}


.PHONY: help-ci

help: help-ci




