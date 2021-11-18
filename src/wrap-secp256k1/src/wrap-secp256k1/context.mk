REPO_SECP256K1 ?= git@github.com:tagion/fork-secp256k1.git
VERSION_SECP256k1 := ea5e8a9c47f1d435e8f66913eb7f1293b85b43f9

DSRC_SECP256K1 := ${call dir.resolve, src}
DIR_SECP256K1 := $(DTMP)/secp256k1

CONFIGUREFLAGS+=--enable-module-ecdh
CONFIGUREFLAGS+=--enable-experimental
CONFIGUREFLAGS+=--enable-module-recovery
CONFIGUREFLAGS+=--enable-module-schnorrsig
CONFIGUREFLAGS+=--enable-shared=no
CONFIGUREFLAGS+= CRYPTO_LIBS=$(DIR_OPENSSL)/lib/ CRYPTO_CFLAGS=$(DIR_OPENSSL)/include/

secp256k1.preconfigure: $(DSRC_SECP256K1)/.src
secp256k1: $(DTMP)/libsecp256k1.a
	@

clean-secp256k1:
	$(PRECMD)$(RMDIR) $(DTMP)/libsecp256k1.a
	$(PRECMD)$(RMDIR) $(DSRC_SECP256K1)

$(DTMP)/%.a: $(DIR_SECP256K1)/.src
	$(PRECMD)cd $(DIR_SECP256K1); ./autogen.sh
	$(PRECMD)cd $(DIR_SECP256K1); ./configure $(CONFIGUREFLAGS)
	$(PRECMD)cd $(DIR_SECP256K1); make clean
	$(PRECMD)cd $(DIR_SECP256K1); make $(MAKE_PARALLEL)
	$(PRECMD)cd $(DIR_SECP256K1); mv .libs/libsecp256k1.a $@

$(DSRC_SECP256K1)/.src:
	$(PRECMD)git clone --depth 1 $(REPO_SECP256K1) $(DSRC_SECP256K1) 2> /dev/null || true
	$(PRECMD)git -C $(DSRC_SECP256K1) fetch --depth 1 $(DSRC_SECP256K1) $(VERSION_SECP256k1) &> /dev/null || true
	$(PRECMD)touch $@