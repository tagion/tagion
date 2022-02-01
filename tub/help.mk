HELPER+=main_help

.PHONY: help

help: help-main

TUB_COMMIT = ${shell cd $(DROOT)/tub; git rev-parse --short HEAD}
TUB_BRANCH = ${shell cd $(DROOT)/tub; git rev-parse --abbrev-ref HEAD}

help-main:
	$(PRECMD)
	${call log.header, $@ :: main}
	${call log.help, "make help-main", "Will display this part"}
	${call log.help, "make help", "Show all helps"}
	${call log.line}
	${call log.help, "make init", "First-time tub initialization (required)"}
	${call log.line}
	${call log.help, "make configure", "Configure units to compile"}
	${call log.help, "make lib<name>", "Compile src/lib-<name>"}
	${call log.help, "make lib*.test", "Compile and execute tests for src/lib-*"}
	${call log.help, "make tagion<name>", "Compile src/bin-<name>"}
	${call log.help, "make *: compile wrapped library | example: make secp256k1"}
	${call log.help, "make clean", "Cleans the generated files from the prime source"}
	${call log.help, "make prober", "Cleans all"}
	${call log.line}
	${call log.help, "make env", "Show Make environment"}
	${call log.line}
	${call log.kvp, "README", "$(DTUB)/README.md"}
	${call log.kvp, "Branch", "$(TUB_BRANCH)"}
	${call log.kvp, "Commit", "$(TUB_COMMIT)"}
	${call log.line}

#	echo "make clone-* BRANCH=<branch>: Clone specific unit"
