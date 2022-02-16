DEPS += lib-hibon
DEPS += wrap-secp256k1

PROGRAM := libcrypto

include ${call dir.resolve, dstep.mk}

# Normal unit config
$(PROGRAM).preconfigure: $(LCRYPTO_DIFILES)

$(PROGRAM).configure: SOURCE := tagion/crypto/*.d tagion/crypto/secp256k1/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a

ifdef TINY_AES
$(PROGRAM).configure: SOURCE += tagion/crypto/aes/tiny_aes/*.d
DCFLAGS+=$(DVERSION)=TINY_AES
else
DEPS += wrap-openssl

$(PROGRAM).configure: SOURCE += tagion/crypto/aes/openssl_aes/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libcrypto.a
endif

