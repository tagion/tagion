

REPORT_ROOT:=$(REPOROOT)/regression
VIEWER_STARTED:=$(REPORT_ROOT)/.report-viewer.touch
VIEWER_INSTALLED:=$(REPORT_ROOT)/.report-install.touch

REPORT_INSTALL:=npm install 
REPORT_VIEWER:=npm run dev
SCREEN_NAME:=node-reporter

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
	echo "$@ not implemented yet"

.PHONY: clean-reporter

clean: clean-reporter

reporter-start:  $(VIEWER_STARTED)  

$(VIEWER_STARTED): $(BDD_LOG)/.way 


$(VIEWER_STARTED):
	$(PRECMD)
	$(CD) $(REPORT_ROOT)
	screen -S $(SCREEN_NAME) -dm $(REPORT_VIEWER) &
	touch $@

-include $(VIEWER_STARTED)

reporter-stop:
	$(PRECMD)
	screen -X -S $(SCREEN_NAME) quit
	$(RM) $(VIEWER_STARTED)


reporter-install: $(VIEWER_INSTALLED)

.PHONY: reporter-install

$(VIEWER_INSTALLED): 
	$(PRECMD)
	$(CD) $(REPORT_ROOT)
	$(REPORT_INSTALL)
	touch $@
	









