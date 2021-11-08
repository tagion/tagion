REPO_SECP256K1 ?= git@github.com:tagion/fork-secp256k1.git
VERSION_SECP256k1 := cd07f5a72243a8f343679aa81ed0d0cb662ba90e

DIR_SECP256K1 := $(DIR_BUILD_WRAPS)/secp256k1

DIR_SECP256K1_PREFIX := $(DIR_SECP256K1)/src/.libs
DIR_SECP256K1_SRC := $(DIR_SECP256K1)/src

wrap-secp256k1: $(DIR_SECP256K1_PREFIX)/libsecp256k1.a
	@

clean-wrap-secp256k1:
	${call unit.dep.wrap-secp256k1}
	${call rm.dir, $(DIR_SECP256K1_SRC)}

$(DIR_SECP256K1_PREFIX)/%.a: wrap-openssl $(DIR_SECP256K1)/.way
	$(PRECMD)git clone --depth 1 $(REPO_SECP256K1) $(DIR_SECP256K1_SRC) 2> /dev/null || true
	$(PRECMD)git -C $(DIR_SECP256K1_SRC) fetch --depth 1 $(DIR_SECP256K1_SRC) $(VERSION_SECP256k1) &> /dev/null || true
	$(PRECMD)cd $(DIR_SECP256K1_SRC); ./autogen.sh
	$(PRECMD)cd $(DIR_SECP256K1_SRC); ./configure CRYPTO_LIBS=$(DIR_OPENSSL)/lib/ CRYPTO_CFLAGS=$(DIR_OPENSSL)/include/
	$(PRECMD)cd $(DIR_SECP256K1_SRC); make clean
	$(PRECMD)cd $(DIR_SECP256K1_SRC); make $(MAKE_PARALLEL)
