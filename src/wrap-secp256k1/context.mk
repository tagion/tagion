DEPS += wrap-openssl

REPO_SECP256K1 ?= git@github.com:tagion/fork-secp256k1.git
VERSION_SECP256k1 := cd07f5a72243a8f343679aa81ed0d0cb662ba90e

DSRC_SECP256K1 := ${call dir.resolve, src}
DTMP_SECP256K1 := $(DTMP)/secp256k1

CONFIGUREFLAGS_SECP256K1 += --enable-module-ecdh
CONFIGUREFLAGS_SECP256K1 += --enable-experimental
CONFIGUREFLAGS_SECP256K1 += --enable-module-recovery
CONFIGUREFLAGS_SECP256K1 += --enable-module-schnorrsig
CONFIGUREFLAGS_SECP256K1 += --enable-shared=no
CONFIGUREFLAGS_SECP256K1 += CRYPTO_LIBS=$(DTMP)/ CRYPTO_CFLAGS=$(DSRC_OPENSSL)/include/

secp256k1: $(DTMP)/libsecp256k1.a
	@

TOCLEAN_SECP256K1 += $(DTMP)/libsecp256k1.a
TOCLEAN_SECP256K1 += $(DTMP_SECP256K1)

TOCLEAN += $(TOCLEAN_SECP256K1)

clean-secp256k1: TOCLEAN := $(TOCLEAN_SECP256K1)
clean-secp256k1: clean
	@

$(DTMP)/libsecp256k1.a: $(DTMP)/.way 
	$(PRECMD)$(CP) $(DSRC_SECP256K1) $(DTMP_SECP256K1)
	$(PRECMD)cd $(DTMP_SECP256K1); ./autogen.sh
	$(PRECMD)cd $(DTMP_SECP256K1); ./configure $(CONFIGUREFLAGS_SECP256K1)
	$(PRECMD)cd $(DTMP_SECP256K1); make clean
	$(PRECMD)cd $(DTMP_SECP256K1); make $(SUBMAKE_PARALLEL)
	$(PRECMD)cd $(DTMP_SECP256K1); mv .libs/libsecp256k1.a $@
