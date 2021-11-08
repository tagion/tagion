DEPS += lib-utils
DEPS += lib-hashgraph
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-communication
DEPS += lib-gossip
DEPS += lib-p2pgowrapper
DEPS += lib-dart
DEPS += lib-monitor

${call config.lib, services}: LOOKUP := tagion/**/*.d
${call config.lib, services}: LOOKUP += tagion/*.d

${call lib, services}: LINKFILES := $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call lib, services}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, services}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call lib, services}: LINKFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a