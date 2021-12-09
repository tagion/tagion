DEPS += lib-wallet
DEPS += lib-communication
DEPS += lib-network
DEPS += lib-crypto
DEPS += lib-options

PROGRAM := tagionwallet

$(PROGRAM).configure: SOURCE := tagion/*.d

$(DBIN)/$(PROGRAM): $(DTMP)/libsecp256k1.a
$(DBIN)/$(PROGRAM): $(DTMP)/libssl.a
$(DBIN)/$(PROGRAM): $(DTMP)/libcrypto.a
