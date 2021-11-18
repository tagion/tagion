include ${call dir.resolve, dstep.mk}

DEPS += lib-hibon
DEPS += wrap-secp256k1

# Normal unit config
libcrypto.preconfigure: $(LCRYPTO_DIFILES)

libcrypto.configure: SOURCE := tagion/crypto/*.d tagion/crypto/secp256k1/*.d

$(DBIN)/libcrypto.test: secp256k1
$(DBIN)/libcrypto.test: INFILES += $(DTMP)/libsecp256k1.a

ifdef TINY_AES
libcrypto.configure: SOURCE += tagion/crypto/aes/tiny_aes/*.d
DCFLAGS+=$(DVERSION)=TINY_AES
else
DEPS += wrap-openssl

libcrypto.configure: SOURCE += tagion/crypto/aes/openssl_aes/*.d

$(DBIN)/libcrypto.test: openssl
$(DBIN)/libcrypto.test: INFILES += $(DTMP)/libssl.a
$(DBIN)/libcrypto.test: INFILES += $(DTMP)/libcrypto.a
endif

