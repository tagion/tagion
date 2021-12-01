.PHONY: help
help:
	${eval TUB_COMMIT := ${shell cd $(DROOT)/tub; git rev-parse --short HEAD}}
	${eval TUB_BRANCH := ${shell cd $(DROOT)/tub; git rev-parse --abbrev-ref HEAD}}
	${call log.header, tub :: $(TUB_BRANCH) ($(TUB_COMMIT)) :: help }
	${call log.kvp, make help, Show this help}
	${call log.kvp, make env, Show Make variables}
	${call log.kvp, make clone-* BRANCH=<branch>, Clone specific unit}
	${call log.kvp, make lib*, Compile src/lib-*}
	${call log.kvp, make lib*.test, Compile and execute tests for src/lib-*}
	${call log.kvp, make tagion*, Compile src/bin-*}
	${call log.kvp, make *, compile wrapped library | example: make secp256k1}
	${call log.kvp, make clean, Clean built and generated files}
	${call log.close}
	${call log.kvp, README}
	${call log.line, $(DTUB)/README.md}
	${call log.close}
