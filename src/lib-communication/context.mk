DEPS += lib-hibon
DEPS += lib-crypto

PROGRAM := libcommunication

$(PROGRAM).configure: SOURCE := tagion/**/*.d

$(DBIN)/$(PROGRAM).test: $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM).test: $(DTMP)/libcrypto.a