DEPS += lib-crypto
DEPS += lib-p2pgowrapper
DEPS += lib-gossip
DEPS += lib-services

${call config.bin, wave}: LOOKUP := tagion/*.d

${call bin, wave}: INFILES += $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
${call bin, wave}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call bin, wave}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
${call bin, wave}: INFILES += $(DIR_BUILD_WRAPS)/p2pgowrapper/lib/libp2pgowrapper.a