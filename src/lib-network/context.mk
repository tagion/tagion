DEPS += lib-hibon
DEPS += lib-communication
DEPS += lib-crypto
DEPS += lib-services
DEPS += lib-hashgraph
DEPS += lib-p2pgowrapper

${call config.lib, network}: LOOKUP := tagion/**/*.d

${call lib, network}: LINKFILES += $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call lib, network}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call lib, network}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, network}: LINKFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a