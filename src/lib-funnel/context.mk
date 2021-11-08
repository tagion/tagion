DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-wallet
DEPS += lib-communication

${call config.lib, funnel}: LOOKUP := tagion/**/*.d

${call lib, funnel}: LINKFILES := $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call lib, funnel}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, funnel}: LINKFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call lib, funnel}: LINKFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a