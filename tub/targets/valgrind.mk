
env-valgrind:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, VALGRIND_TOOL, $(VALGRIND_TOOL)}
	${call log.env, VALGRIND_FLAGS, $(VALGRIND_FLAGS)}
	${call log.close}

.PHONY: env-valgrind

env: env-valgrind

help-valgrind:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make VALGRIND=1 <target>", "Set the valgrind"}
	${call log.close}

.PHONY: help-valgrind

help: help-valgrind
