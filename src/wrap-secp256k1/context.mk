DEPS += wrap-openssl

REPO_SECP256K1 ?= git@github.com:tagion/fork-secp256k1.git
VERSION_SECP256k1 := ea5e8a9c47f1d435e8f66913eb7f1293b85b43f9

DSRC_SECP256K1 := ${call dir.resolve, src}
DTMP_SECP256K1 := $(DTMP)/secp256k1

CONFIGUREFLAGS_SECP256K1 += --enable-module-ecdh
CONFIGUREFLAGS_SECP256K1 += --enable-experimental
CONFIGUREFLAGS_SECP256K1 += --enable-module-recovery
CONFIGUREFLAGS_SECP256K1 += --enable-module-schnorrsig
CONFIGUREFLAGS_SECP256K1 += --enable-shared=no
CONFIGUREFLAGS_SECP256K1 += CRYPTO_LIBS=$(DTMP)/ CRYPTO_CFLAGS=$(DSRC_OPENSSL)/include/

secp256k1.preconfigure: $(DSRC_SECP256K1)/.src
secp256k1: $(DTMP)/libsecp256k1.a
	@

TOCLEAN_SECP256K1 += $(DTMP)/libsecp256k1.a
TOCLEAN_SECP256K1 += $(DSRC_SECP256K1)
TOCLEAN_SECP256K1 += $(DTMP_SECP256K1)

TOCLEAN += $(TOCLEAN_SECP256K1)

clean-secp256k1: TOCLEAN := $(TOCLEAN_SECP256K1)
clean-secp256k1: clean
	@

$(DTMP)/libsecp256k1.a: $(DTMP)/.way $(DSRC_SECP256K1)/.src
	$(PRECMD)$(CP) $(DSRC_SECP256K1) $(DTMP_SECP256K1)
	$(PRECMD)cd $(DTMP_SECP256K1); ./autogen.sh
	$(PRECMD)cd $(DTMP_SECP256K1); ./configure $(CONFIGUREFLAGS_SECP256K1)
	$(PRECMD)cd $(DTMP_SECP256K1); make clean
	$(PRECMD)cd $(DTMP_SECP256K1); make $(MAKE_PARALLEL)
	$(PRECMD)cd $(DTMP_SECP256K1); mv .libs/libsecp256k1.a $@

$(DSRC_SECP256K1)/.src:
	$(PRECMD)git clone --depth 1 $(REPO_SECP256K1) $(DSRC_SECP256K1) 2> /dev/null || true
	$(PRECMD)git -C $(DSRC_SECP256K1) fetch --depth 1 $(DSRC_SECP256K1) $(VERSION_SECP256k1) &> /dev/null || true
	$(PRECMD)touch $@