DEPS += wrap-openssl

DSRC_SECP256K1 := ${call dir.resolve, src}
DTMP_SECP256K1 := $(DTMP)/secp256k1

CONFIGUREFLAGS_SECP256K1 += --enable-module-ecdh
CONFIGUREFLAGS_SECP256K1 += --enable-experimental
CONFIGUREFLAGS_SECP256K1 += --enable-module-recovery
CONFIGUREFLAGS_SECP256K1 += --enable-module-schnorrsig
CONFIGUREFLAGS_SECP256K1 += --enable-shared=no
CONFIGUREFLAGS_SECP256K1 += CRYPTO_LIBS=$(DTMP)/ CRYPTO_CFLAGS=$(DSRC_OPENSSL)/include/

include ${call dir.resolve, cross.mk}

secp256k1: $(DTMP)/libsecp256k1.a
	@

TOCLEAN_SECP256K1 += $(DTMP)/libsecp256k1.a
TOCLEAN_SECP256K1 += $(DTMP_SECP256K1)

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

MAKE_ENV += env-secp256k1
env-secp256k1:
	$(PRECMD)
	$(call log.header, env :: secp256k1)
	$(call log.kvp, CONFIGUREFLAGS_SECP256K1)
	$(call log.lines, $(CONFIGUREFLAGS_SECP256K1))
	$(call log.close)
