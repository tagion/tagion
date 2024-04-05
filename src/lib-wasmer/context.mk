include ${call dir.resolve, dstep.mk}

env-wasmer:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, WASMER_ROOT,$(WASMER_ROOT))
	$(call log.kvp, WASMER_PACKAGE,$(WASMER_PACKAGE))
	$(call log.close)

.PHONY: env-wasmer

env: env-wasmer

help-wasmer:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.help, "make env-dstep-$(WASMER_PACKAGE)", "Display wasmer dstep env")
	$(call log.close)

help: help-wasmer

.PHONY: help-wasmer

