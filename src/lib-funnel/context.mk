DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-wallet
DEPS += lib-communication

libfunnel.configure: SOURCE := tagion/**/*.d

$(DBIN)/libfunnel.test: $(DTMP)/libsecp256k1.a
$(DBIN)/libfunnel.test: $(DTMP)/libssl.a
$(DBIN)/libfunnel.test: $(DTMP)/libcrypto.a
$(DBIN)/libfunnel.test: $(DTMP)/libp2pgowrapper.a