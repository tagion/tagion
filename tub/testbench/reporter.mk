

export REPORT_ROOT=$(REPOROOT)/regression

REPORT_INSTALL:=npm install 
export REPORT_VIEWER:=npm run dev
export REPORTER_NAME:=node-reporter

env-reporter:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, REPORT_ROOT, $(REPORT_ROOT)}
	${call log.env, REPORT_VIEWER, $(REPORT_VIEWER)}
	${call log.close}

.PHONY: env-reporter

help-reporter:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make reporter-start", "Will start the reporter on localhost"}
	${call log.help, "make reporter-install", "Will install npm dependencies"}
	${call log.help, "make reporter-stop", "Will stop the reporter"}
	${call log.help, "make clean-reporter", "Will clean the test reports"}
	${call log.help, "make env-reporter", "Display the reporter env"}
	${call log.help, "make list-bdd", "List all bdd targets"}
	${call log.close}

.PHONY: help-reporter

help: help-reporter

clean-reporter:
	$(PRECMD)
	$(RMDIR) $(BDD_RESULTS)

.PHONY: clean-reporter

clean: clean-reporter

reporter-start: reporter-install
	$(PRECMD)
	$(SCRIPTS)/reporter_start.sh start 

reporter-stop:
	$(PRECMD)
	$(SCRIPTS)/reporter_start.sh stop 

reporter-install: $(VIEWER_INSTALLED)

.PHONY: reporter-install

$(VIEWER_INSTALLED): 
	$(PRECMD)
	$(CD) $(REPORT_ROOT)
	$(REPORT_INSTALL)
	touch $@

.PHONY: reporter-start reporter-stop reporter-install

