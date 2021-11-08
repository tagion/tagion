DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-utils
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip

${call config.lib, hashgraph}: LOOKUP := tagion/**/*.d

${call lib, hashgraph}: LINKFILES := $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call lib, hashgraph}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, hashgraph}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call lib, hashgraph}: LINKFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a