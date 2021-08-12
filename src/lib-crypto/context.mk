# ifeq ($(OS),Darwin)
# LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity -L-framework -LCryptoKit
# endif

ctx/lib/crypto: ctx/lib/hibon ctx/wrap/secp256k1 ctx/wrap/openssl