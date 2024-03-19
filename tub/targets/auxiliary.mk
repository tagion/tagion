#
# Auxiliary variables
#

env-aux: env-auxiliary

env-auxiliary:
	$(PRECMD)
	${call log.header, $@ :: env}
	${call log.kvp, DC, $(DC)}
	${call log.kvp, PRECMD, $(PRECMD)}
	${call log.kvp, SHARED, $(SHARED)}
	${call log.kvp, SPLIT_LINK, $(SPLIT_LINK)}
	${call log.kvp, DLLEXT, $(DLLEXT)}
	${call log.kvp, STAEXT, $(STAEXT)}
	${call log.kvp, OBJEXT, $(OBJEXT)}
	${call log.kvp, LDC2_BIN, $(LDC2_BIN)}
	${call log.close}

env: env-auxiliary

help-aux: help-auxiliary

help-auxiliary:
	$(PRECMD)
	${call log.header, $@ :: help}
	${call log.kvp, "This is list parameter which can be change from command line macros"}
	${call log.help, DC, "This is the d compiler used"}
	${call log.help, PRECMD, "The pre-command macro (Default @) 'make PRECMD=' will echo all commands"}
	${call log.help, SHARED, "This switch can be set to 1 to enable shard lib eg .$(DLLEXT) file"}
	${call log.help, SPLIT_LINK, "Will spilt the linking and compile process for cross compilations"}
	${call log.close}

help: help-auxiliary

.PHONY: help-auxiliary env-auxiliary
