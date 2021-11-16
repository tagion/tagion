DEPS += lib-hibon

ifdef TEST
DEPS += wrap-secp256k1

${call config.lib, crypto}: wrap-secp256k1
endif

${call config.lib, crypto}: LOOKUP := tagion/crypto/*.d
${call config.lib, crypto}: LOOKUP += tagion/crypto/secp256k1/*.d

${call lib, crypto}: INFILES += $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a

ifdef TINY_AES
${call config.lib, crypto}: LOOKUP += tagion/crypto/aes/tiny_aes/*.d
DCFLAGS+=$(DVERSION)=TINY_AES
else

ifdef TEST
DEPS += wrap-openssl
${call config.lib, crypto}: wrap-openssl
endif

${call config.lib, crypto}: LOOKUP += tagion/crypto/aes/openssl_aes/*.d

${call lib, crypto}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, crypto}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
endif

