
WASMER_DIR=$(DSRC)/fork-wasmer/wasmer

ifdef ENABLE_WASMER

ifeq ($(PLATFORM),$(LINUX_X86_64))
	WASMER_TARGET:=x86_64-unknown-linux-gnu
endif

ifdef WASMER_TARGET
LIBWASMER=$(WASMER_DIR)/target/$(WASMER_TARGET)/release/libwasmer.a
endif

endif
