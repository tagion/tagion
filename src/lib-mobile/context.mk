DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-funnel
DEPS += lib-wallet
DEPS += lib-communication

libmobile.configure: SOURCE := tagion/**/*.d

$(DBIN)/libmobile.test: $(DTMP)/libsecp256k1.a
$(DBIN)/libmobile.test: $(DTMP)/libssl.a
$(DBIN)/libmobile.test: $(DTMP)/libcrypto.a