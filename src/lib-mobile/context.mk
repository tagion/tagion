DEPS += lib-basic
DEPS += lib-hibon
DEPS += lib-crypto
DEPS += lib-funnel
DEPS += lib-wallet
DEPS += lib-communication

PROGRAM := libmobile

$(PROGRAM).configure: SOURCE := tagion/**/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libcrypto.a
