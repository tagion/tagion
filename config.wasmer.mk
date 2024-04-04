

#WASMER_DIR=$(DBUILD)/wasmer

WASMER_MANIFEST:=lib/c-api/Cargo.toml

WASMER_FLAG+=--no-default-features
WASMER_FLAG+=--features wat,wasi,middlewares
WASMER_FLAG+=--features cranelift
WASMER_FLAG+=--release

ifdef ENABLE_WASMER
DFLAGS+=$(DVERSION)=ENABLE_WASMER
endif
