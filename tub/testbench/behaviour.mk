
bdd:
	echo $(BEHAVIOUR)
	echo $(DINC)

env-bdd:
	$(PRECMD)
	${call log.header, $$@ :: env}
	${call log.env, BDD_FLAGS, $(BDD_FLAGS)}
	${call log.close}

.PHONY: env-bdd

env: env-bdd

help-bdd:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.help, "make help-bdd", "Will display this part"}
	${call log.help, "make bdd", "Generated the bdd files"}
	${call log.close}
