.PHONY: $(REVISION_FILE)

$(REVISION_FILE): $(DBUILD)/.way
	$(PRECMD)
	${call log.header, revision :: $(shell date +'%F %H:%M')}
	echo 'version: $(VERSION_STRING)' > $@
	echo 'git: $(GIT_INFO)' >> $@
	echo 'branch: $(GIT_BRANCH)' >> $@
	echo 'hash: $(GIT_HASH)' >> $@
	echo 'revno: $(GIT_REVNO)' >> $@
	echo 'builder_name: $(GIT_USER)' >> $@
	echo 'builder_email: $(GIT_EMAIL)' >> $@
	echo 'build_date:  $(BUILD_DATE)' >> $@
	echo 'CC: $(CC_VERSION)' >> $@
	echo 'DC: $(DC_VERSION)' >> $@

revision: $(REVISION_FILE)


.PHONY: revision

clean-revision:
	$(PRECMD)
	${call log.header, $@ :: clean}
	$(RM) $(REVISION_FILE)
	${call log.close}

.PHONY: clean-revision

help-revision:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-revision", "Will display this part"}
	${call log.help, "make revision", "Creates the $(REVISION_MODULE) module"}
	${call log.help, "make clean-revision", "Erase the revision module"}
	${call log.close}

help: help-revision

.PHONY: help-revision

env-revision:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, REVISION_MODULE, $(REVISION_MODULE)}
	${call log.kvp, REVISION_FILE, $(REVISION_FILE)}
	${call log.close}

.PHONY: env-revision

env: env-revision

