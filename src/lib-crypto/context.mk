include ${call dir.resolve, dstep.mk}

DEPS += lib-hibon
DEPS += wrap-secp256k1

# Normal unit config
libcrypto.preconfigure: $(LCRYPTO_DIFILES)

libcrypto.configure: SOURCE := tagion/crypto/*.d tagion/crypto/secp256k1/*.d

libcrypto.test.configure: INFILES += $(DTMP)/secp256k1/lib/libsecp256k1.a

ifdef TINY_AES
libcrypto.configure: SOURCE += tagion/crypto/aes/tiny_aes/*.d
DCFLAGS+=$(DVERSION)=TINY_AES
else
DEPS += wrap-openssl

libcrypto.configure: SOURCE += tagion/crypto/aes/openssl_aes/*.d

libcrypto.test.configure: INFILES += $(DTMP)/openssl/lib/libssl.a
libcrypto.test.configure: INFILES += $(DTMP)/openssl/lib/libcrypto.a
endif

