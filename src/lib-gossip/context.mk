DEPS += lib-hibon
DEPS += lib-utils
DEPS += lib-crypto
DEPS += lib-hashgraph
DEPS += lib-dart
DEPS += lib-communication
DEPS += lib-p2pgowrapper

${call config.lib, gossip}: LOOKUP := tagion/gossip/*.d

${call lib, gossip}: LINKFILES := $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call lib, gossip}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, gossip}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call lib, gossip}: LINKFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a