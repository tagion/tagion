
env-valdgrind:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.env, VALDGRIND_FLAGS, $(VALDGRIND_FLAGS)}
	${call log.close}

.PHONY: env-valdgrind

env: env-valdgrind

help-valdgrind:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make VALDGRIND=1 <target>", "Set the valdgrind"}
	${call log.close}

.PHONY: help-valgrind

help: help-valdgrind
