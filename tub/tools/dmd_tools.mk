DMD_BIN?=${abspath ${dir ${shell which dmd}}}

ifneq (${strip DMD_BIN},)
DMD?=$(DMD_BIN)/dmd
LDMD2?=$(DMD_BIN)/ldmd2
LDC-BUILD-RUNTIME?=$(DMD_BIN)/ldc-build-runtime
endif

env-dmd:
	$(PRECMD)
	$(call log.header, $@ :: env)
	${call log.kvp, DMD_BIN, $(DMD_BIN)}
	${call log.kvp, DMD, $(DMD)}
	${call log.kvp, LDMD2, $(LDMD2)}
	${call log.kvp, LDC-BUILD-RUNTIME, $(LDC-BUILD-RUNTIME)}
	${call log.close}

.PHONY: env-dmd

env: env-dmd
