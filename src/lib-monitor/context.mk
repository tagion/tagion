DEPS += lib-basic
DEPS += lib-hashgraph
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip
DEPS += lib-dart
DEPS += lib-network
DEPS += lib-funnel
DEPS += lib-p2pgowrapper

${call config.lib, monitor}: LOOKUP := tagion/**/*.d

${call lib, monitor}: INFILES += $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call lib, monitor}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, monitor}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call lib, monitor}: INFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a