.PHONY: $(REVISION_FILE)

$(REVISION_FILE): $(DBUILD)/.way
	$(PRECMD)
	${call log.header, revision :: $(GIT_DATE)}
	echo '$(GIT_INFO)' > $@
	echo '$(GIT_BRANCH)' >> $@
	echo '$(GIT_HASH)' >> $@
	echo '$(GIT_REVNO)' >> $@
	echo '$(GIT_DATE)' >> $@
	echo '$(GIT_USER)' >> $@
	echo '$(GIT_EMAIL)' >> $@
	echo '$(CC_VERSION)' >> $@
	echo '$(DC_VERSION)' >> $@

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

