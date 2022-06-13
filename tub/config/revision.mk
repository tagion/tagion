.PHONY: $(REVISION_FILE)

$(REVISION_FILE):
	$(PRECMD)
	echo "module $(REVISION_MODULE);" > $@
	echo 'enum REVNO=$(GIT_REVNO);' >> $@
	echo 'enum HASH="$(GIT_HASH)";' >> $@
	echo 'enum INFO="$(GIT_INFO)";' >> $@
	echo 'enum DATA="$(GIT_DATE)";' >> $@
	echo 'import std.format;' >> $@
	echo 'import std.array : join;' >> $@
	echo 'enum version_text = format(["git :%s", "hash:%s", "revno:%s", "date:%s"].join("\n"), INFO, HASH, REVNO, DATE);' >>  $@

revision: $(REVISION_FILE)
	echo $(REVISION_FILE)

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
