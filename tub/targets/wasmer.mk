
ifdef WASMER_TARGET
$(LIBWASMER): libwasmer

libwasmer:
	$(PRECMD)
	$(call log.header, $@ :: libwasmer)
	$(CD) $(WASMER_DIR)
	cargo build --manifest-path $(WASMER_MANIFEST) $(WASMER_FLAG) --target $(WASMER_TARGET)

proper-libwasmer:
	$(PRECMD)
	$(call log.header, $@ :: proper)
	$(CD) $(WASMER_DIR)
	cargo clean --manifest-path $(WASMER_MANIFEST)

.PHONY: proper-libwasmer

proper: proper-libwasmer

else
libwasmer: 
	$(warning wasmer not supported of $(PLATFORM) or it's not enabled with ENABLE_WASMER)
endif

help-libwasmer:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.help, "make libwasmer", "Compiles the libwasmer")  
	$(call log.help, "make proper-libwasmer", "Remove the pre-build of wasmer")
	$(call log.help, "make env-libwasmer", "Show the environment for libwasmer")
	$(call log.close)

env-libwasmer:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, WASMER_TARGET, $(WASMER_TARGET))
	$(call log.kvp, LIBWASMER, $(LIBWASMER))
	$(call log.kvp, WASMER_DIR, $(WASMER_DIR))
	$(call log.kvp, WASMER_MANIFEST, $(WASMER_MANIFEST))
	$(call log.close)

.PHONY: env-libwasmer

env: env-libwasmer


