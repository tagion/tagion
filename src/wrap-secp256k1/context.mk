REPO_SECP256K1 ?= https://github.com/bitcoin-core/secp256k1.git
DIR_SECP256K1_SRC := ${call dir.self, secp256k1}
DIR_SECP256K1_BUILD := $(DIR_BUILD)/wraps/secp256k1

WAYS_PERSISTENT += $(DIR_SECP256K1_BUILD)/.way
WAYS_PERSISTENT += $(DIR_SECP256K1_BUILD)/lib/.way
WAYS_PERSISTENT += $(DIR_SECP256K1_SRC)/.libs/.way

wrap-secp256k1: | ways wrap-openssl $(DIR_SECP256K1_BUILD)/lib/libsecp256k1.a
	${eval WRAPS += secp256k1}
	${eval WRAPS_STATIC += $(DIR_SECP256K1_BUILD)/lib/libsecp256k1.a}

$(DIR_SECP256K1_BUILD)/lib/libsecp256k1.a: $(DIR_SECP256K1_SRC)/.libs/libsecp256k1.a
	$(PRECMD)cp $(DIR_SECP256K1_SRC)/.libs/libsecp256k1.a $(DIR_SECP256K1_BUILD)/lib/libsecp256k1.a

$(DIR_SECP256K1_SRC)/.libs/libsecp256k1.a: $(DIR_SECP256K1_SRC)/Makefile
	$(PRECMD)cd $(DIR_SECP256K1_SRC); make clean
	$(PRECMD)cd $(DIR_SECP256K1_SRC); make

$(DIR_SECP256K1_SRC)/Makefile: $(DIR_SECP256K1_SRC)/configure
	$(PRECMD)cd $(DIR_SECP256K1_SRC); ./configure CRYPTO_LIBS=$(DIR_BUILD_OPENSSL)/lib/ CRYPTO_CFLAGS=$(DIR_BUILD_OPENSSL)/include/

$(DIR_SECP256K1_SRC)/configure: $(DIR_SECP256K1_SRC)/autogen.sh
	$(PRECMD)cd $(DIR_SECP256K1_SRC); ./autogen.sh

$(DIR_SECP256K1_SRC)/autogen.sh:
	$(PRECMD)git -C $(DIR_SECP256K1_SRC) pull || git clone --depth 1 $(REPO_SECP256K1) $(DIR_SECP256K1_SRC)
