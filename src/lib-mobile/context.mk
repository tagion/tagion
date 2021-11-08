DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-funnel
DEPS += lib-communication

${call config.lib, wallet}: LOOKUP := tagion/**/*.d

${call lib, wallet}: INFILES += $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call lib, wallet}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, wallet}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a