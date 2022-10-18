
VIEWER_STARTED:=/tmp/$(HONE).report-viewer.pid.mk

REPORT_ROOT:=$(REPOROOT)/regression

REPORT_VIEWER:=npm run dev

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
	${call log.help, "make reporter-stop", "Will stop the reporter"}
	${call log.help, "make clean-reporter", "Will clean the test reports"}
	${call log.help, "make env-reporter", "Display the reporter env"}
	${call log.close}


.PHONY: help-reporter

help: help-reporter

clean-reporter:
	$(PRECMD)
	echo "$@ not implemented yet"

.PHONY: clean-reporter

clean: clean-reporter

reporter-start: $(VIEWER_STARTED)

$(VIEWER_STARTED):
	$(PRECMD)
	$(CD) $(REPORT_ROOT)
	$(REPORT_VIEWER) &
	echo "export REPORT_VIEWER_PID=$$!" > $@

-include $(VIEWER_STARTED)

ifdef REPORT_VIEWER_PID
reporter-stop:
	$(PRECMD)
	kill -HUP $(REPORT_VIEWER_PID)
	$(RM) $(VIEWER_STARTED)
else
reporter-stop:
	$(PRECMD)
endif







