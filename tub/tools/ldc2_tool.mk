LDC2_BIN?=${abspath ${dir ${shell which ldc2}}}

ifneq (${strip LDC2_BIN},)
LDC2?=$(LDC2_BIN)/ldc2
LDMD2?=$(LDC2_BIN)/ldmd2
LDC-BUILD-RUNTIME?=$(LDC2_BIN)/ldc-build-runtime
endif

env-ldc2:
	$(PRECMD)
	$(call log.header, $@ :: env)
	${call log.kvp, LDC2_BIN, $(LDC2_BIN)}
	${call log.kvp, LDC2, $(LDC2)}
	${call log.kvp, LDMD2, $(LDMD2)}
	${call log.kvp, LDC-BUILD-RUNTIME, $(LDC-BUILD-RUNTIME)}
	${call log.close}

.PHONY: env-ldc2

env: env-ldc2
