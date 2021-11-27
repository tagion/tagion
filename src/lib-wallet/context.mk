DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-funnel
DEPS += lib-communication

libwallet.configure: SOURCE := tagion/**/*.d

$(DBIN)/libwallet.test: $(DTMP)/libsecp256k1.a
$(DBIN)/libwallet.test: $(DTMP)/libssl.a
$(DBIN)/libwallet.test: $(DTMP)/libcrypto.a