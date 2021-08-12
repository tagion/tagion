# Clone and make according to variables
# Will add support for crossc compilation triplet and choose dest folder automatically.

NAME_SECP256K1 := secp256k1
REPO_SECP256K1 ?= https://github.com/bitcoin-core/secp256k1.git
PATH_SRC_SECP256K1 := ${dir.self}/$(NAME_SECP256K1)

check/secp256k1:
	${call log.line, System check for secp256k1 is not implemented yet}

wrap/secp256k1: ways $(PATH_SRC_SECP256K1)/.libs/libsecp256k1.a
	${eval WRAPS += secp256k1}
	${eval WRAPLIBS += $(PATH_SRC_SECP256K1)/.libs/libsecp256k1.a}

$(PATH_SRC_SECP256K1)/autogen.sh:
	$(PRECMD)git -C $(PATH_SRC_SECP256K1) pull || git clone $(REPO_SECP256K1) $(PATH_SRC_SECP256K1)

$(PATH_SRC_SECP256K1)/configure: $(PATH_SRC_SECP256K1)/autogen.sh
	$(PRECMD)cd $(PATH_SRC_SECP256K1); ./autogen.sh

$(PATH_SRC_SECP256K1)/Makefile: $(PATH_SRC_SECP256K1)/configure
	$(PRECMD)cd $(PATH_SRC_SECP256K1); ./configure

$(PATH_SRC_SECP256K1)/.libs/libsecp256k1.a: $(PATH_SRC_SECP256K1)/Makefile
	$(PRECMD)cd $(PATH_SRC_SECP256K1); make clean && make