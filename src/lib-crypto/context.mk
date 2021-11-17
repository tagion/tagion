include dstep.mk

DEPS += lib-hibon
DEPS += wrap-secp256k1

${call config.lib, crypto}: wrap-secp256k1

ifdef TEST
${call lib, crypto}: INFILES += $(DIR_BUILD_WRAPS)/secp256k1/lib/libsecp256k1.a
endif
${call lib.o, crypto}: INCLFLAGS += $(DIR_BUILD_WRAPS)/secp256k1/src

${call config.lib, crypto}: LOOKUP := tagion/crypto/*.d
${call config.lib, crypto}: LOOKUP += tagion/crypto/secp256k1/*.d


ifdef TINY_AES
${call config.lib, crypto}: LOOKUP += tagion/crypto/aes/tiny_aes/*.d
DCFLAGS+=$(DVERSION)=TINY_AES
else
DEPS += wrap-openssl

${call config.lib, crypto}: wrap-openssl

ifdef TEST
${call lib, crypto}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libssl.a
${call lib, crypto}: INFILES += $(DIR_BUILD_WRAPS)/openssl/lib/libcrypto.a
endif

${call config.lib, crypto}: LOOKUP += tagion/crypto/aes/openssl_aes/*.d

endif

